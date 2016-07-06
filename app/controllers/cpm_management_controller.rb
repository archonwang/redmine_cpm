class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global, :only => [:show]
  before_filter :set_menu_item
  before_filter :oauth_authentication, :only => :show, :unless => :oauth_token?

  helper :cpm_management, :cpm_app

  def oauth_token?
    !Setting.plugin_redmine_cpm[:google_calendar].present? or session[:oauth_token].present?
  end

  # Main page for capacities search and management
  def show
    # get all filter names
    @filters = CpmUserCapacity.get_filter_names
    
    # get all filters activated by params
    @active_filters = []
    @active_custom_field_filters = []
    @filters.collect{|f| f[1]}.each do |filter|
      if params[filter].present?
        @active_filters << filter
      elsif params['custom_field'].present? and params['custom_field'].include?(filter)
        @active_custom_field_filters << filter
      end
    end

    # if there are no active filters, show users filter
    if @active_filters.empty? and @active_custom_field_filters.empty?
      @active_filters << 'users'
    end

    # for each activated filter, load it
    @active_filters.each do |active_filter|
      eval("get_filter_"+active_filter)
    end

    @active_custom_field_filters.each do |active_custom_field_filter|
      get_filter_custom_field(active_custom_field_filter)
    end

    # process planning table
    if params[:commit].present?
      planning
    end
  end

  # Capacity search result
  def planning
    # if google calendar integration is activated, get google calendar info
    if Setting.plugin_redmine_cpm[:google_calendar].present?
      get_calendar
    end

    # users and projects to show in planning table
    @users = []
    @projects = []

    # getting @projects array
    # add projects specified by project filter
    if params[:projects].present?
      @projects = CPM::Filters.projects(params[:projects])
    else
      @projects = Project.allowed(params['ignore_black_lists'].present?).collect{|p| p.id} #.sort_by{|p| p.name}
    end

    # add projects specified by project manager filter
    if params[:project_manager].present?
      @projects = CPM::Filters.project_manager(params[:project_manager], @projects)
    end

    # filter projects if custom field filters are specified
    if params[:custom_field].present?
      @projects = CPM::Filters.custom_field(params[:custom_field], @projects)
    end


    if !@projects.empty?
      # getting @users array
      # add users specified by users filter
      if params[:users].present?
        @users = CPM::Filters.projects(params[:users])
      else
        @users = User.allowed(params['ignore_black_lists'].present?).collect{|u| u.id}
      end

      # add users specified by groups filter
      if params[:groups].present?
        @users = CPM::Filters.groups(params[:groups], @users)
      end
      
      # knowledge filter
      if params[:knowledges].present?
        @users = CPM::Filters.knowledges(params[:knowledges], @users)
      end
    end

    # get projects objects
    if @projects.present?
      @projects = Project.where("id IN (?)",@projects).map(&:self_and_descendants).flatten.uniq.sort_by{|p| p.name}
    else
      @projects = []
    end

    # get users objects
    # if there are NO users filters active, get users based on projects selected
    if !params[:users].present? and !params[:groups].present? and !params[:knowledges].present?
      # get users who are project members
      members = Member.select("user_id").where("project_id IN (?)", @projects).collect(&:user_id)
      # get users who have time entries in projects
      time_entries = TimeEntry.select("user_id").where("project_id IN (?)", @projects).collect(&:user_id)

      users_not_allowed = User.not_allowed(params['ignore_black_lists'].present?)
      @users = User.where("id IN (?)", (members+time_entries).uniq).reject{|u| users_not_allowed.include?((u.id).to_s)}.sort_by{|u| u.login}
    elsif @users.present?
      @users = User.where("id IN (?)",@users).sort_by{|u| u.login}
    else
      @users = []
    end

    # set time_unit and time_unit_num default values
    @time_unit = params[:time_unit] || 'week'
    @time_unit_num = (params[:time_unit_num] || 12).to_i

    # if google calendar integration is activated, create new capacities for each entry
    if @calendar.present?
      absence_project_id = Setting.plugin_redmine_cpm['absence_project']
      if absence_project_id.present?
        holidays = {}
        @users.each do |user|
          holidays[user.id] = []
          if @calendar[user.login].present?
            @calendar[user.login].each do |cpm|
              holidays[user.id] << CpmUserCapacity.new(user_id: user.id, project_id: absence_project_id, capacity: 100, from_date: cpm[0].to_datetime, to_date: cpm[1].to_datetime)
            end
          end
        end
      end
    end

    # create object for result table info
    @capacities = {}
    @users.each do |user|
      @capacities[user.id] = @time_unit_num.times.collect{|i| {'value' => 0.0, 'tooltip' => ""}}
      
      # get all user capacities
      capacities = CpmUserCapacity.where('user_id = ? AND project_id IN(?) AND to_date >= ?',user.id, @projects.map{|p| p.id.to_s}, DateTime.now)
      capacities += holidays[user.id] if holidays.present?

      capacities.each do |capacity|
        # for each user capacity, update respective table cell
        @time_unit_num.times do |i|
          start_day = CPM::CpmDate.get_start_date(@time_unit,i)
          end_day = CPM::CpmDate.get_due_date(@time_unit,i)
          @capacities[user.id][i]['value'] += capacity.get_relative(start_day, end_day)
          @capacities[user.id][i]['tooltip'] += capacity.get_tooltip(start_day, end_day)
        end
      end
    end
    
    # if request is called from AJAX, update only 'planning' partial
    if request.xhr?
      render "cpm_management/_planning" ,layout: false
    end
  end

  # Capacity edit form
  def edit_form
    user = User.find_by_id(params[:user_id])

    # get all available projects
    all_projects = Project.allowed(params['ignore_black_lists'].present?).sort_by{|p| p.name}

    if params[:projects].present?
      projects = params[:projects]
    else
      projects = all_projects.collect{|p| p.id}
    end
    
    @from_date = Date.strptime(params[:from_date], "%d/%m/%y")
    @to_date = Date.strptime(params[:to_date], "%d/%m/%y")

    # load pojects options
    @projects_for_selection = all_projects.collect{|p| [p.name,p.id]}
    
    if projects.present?
      @default_project = projects[0]
    else
      @default_project = nil
    end

    @capacities = user.get_range_capacities(@from_date,@to_date,projects)

    # show warning notice if user capacity is over 100
    @capacities.each do |c|
      if !c.check_capacity(Project.not_allowed(params['ignore_black_lists'].present?))
        flash[:warning] = l(:"cpm.msg_capacity_higher_than_100")
      end
    end

    @cpm_user_capacity = CpmUserCapacity.new
    @cpm_user_capacity.user_id = params[:user_id]

    render layout: false
  end

# Search filters
  def get_filter_users
    @users_selected = []
    if params['users'].present?
      @users_selected = params['users']
    end

    @users_options = User.allowed(params['show_all_users']).sort_by{|u| u.login}.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/users', :layout => false, :locals => { :options => @users_options }) }
    end
  end

  def get_filter_groups
    ignored_groups = Setting.plugin_redmine_cpm['ignored_groups'] || [0]
    if params['show_all_groups'].present?
      ignored_groups = [0]
    end

    @groups_selected = []
    if params['groups'].present?
      @groups_selected = params['groups']
    end

    @groups_options = Group.where("id NOT IN (?)", ignored_groups).sort_by{|g| g.name}.collect{|g| [g.name, (g.id).to_s]}
    
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/groups', :layout => false, :locals => { :options => @groups_options }) }
    end
  end

  def get_filter_projects
    @projects_selected = []
    if params['projects'].present?
      @projects_selected = params['projects']
    end

    @projects_options = Project.allowed(params['show_all_projects']).sort_by{|p| p.name}.collect{|p| [p.name, (p.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/projects', :layout => false, :locals => { :options => @projects_options }) }
    end
  end

  def get_filter_project_manager
    project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];

    users = User.get_by_role(project_manager_role)

    @project_manager_selected = []
    if params['project_manager'].present?
      @project_manager_selected = params['project_manager']
    end

    @project_manager_options = users.uniq.sort.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/project_manager', :layout => false, :locals => { :options => @project_manager_options }) }
    end
  end

  def get_filter_custom_field(custom_field_id=nil)
    custom_field = CustomField.find_by_id(params[:custom_field_id] || custom_field_id)

    @custom_field_options ||= {}
    @custom_field_size ||= {}
    @custom_field_name ||= {}
    @custom_field_selected ||= {}
    case custom_field.field_format
      when 'list'
        @custom_field_name[custom_field.id.to_s] = custom_field.name
        @custom_field_options[custom_field.id.to_s] = custom_field.possible_values.collect{|o| [o, o]}
        @custom_field_size[custom_field.id.to_s] = ([10,@custom_field_options[custom_field.id.to_s].count].min).to_s

        if params['custom_field'].present?
          @custom_field_selected[custom_field.id.to_s] = params['custom_field'][custom_field.id.to_s] || []
        end

        if request.xhr?
          render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/custom_field_list', :layout => false, :locals => { :id => custom_field.id }) }
        end
    end

  end

  def get_filter_time_unit
    @time_unit_options = ['day','week','month'].collect{|tu| [l(:"cpm.label_#{tu}"), tu]}
    @time_unit_selected = params['time_unit'] || 'week'

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit', :layout => false )}
    end
  end

  def get_filter_time_unit_num
    @value = params['time_unit_num'] || '12';
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/time_unit_num', :layout => false )}
    end
  end

  def get_filter_ignore_black_lists
    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/ignore_black_lists', :layout => false )}
    end
  end

  def get_filter_knowledges
    @knowledges_selected = []
    if params['knowledges'].present?
      @knowledges_selected = params['knowledges']
    end

    if params['show_all_knowledges'].present?
      @knowledges_options = Knowledge.name_options
    else
      @knowledges_options = Knowledge.main_options
    end

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/knowledges', :layout => false, :locals => { :options => @knowledges_options }) }
    end
  end
  

# Google Calendar
  def oauth_authentication
    session[:params] = params
    redirect_to oauth_client.auth_code.authorize_url(:redirect_uri => oauth_callback_url, :scope => scopes, :access_type => 'offline', :approval_prompt => 'force')
  end

  def oauth_callback
    token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => oauth_callback_url)
    session[:oauth_token] = (token.to_hash).to_json

    params = session[:params]

    redirect_to :action => 'show', :params => params
  end

  def get_calendar  
    begin
      calendar = {}

      calendar_id = Setting.plugin_redmine_cpm[:calendar_id]

      if calendar_id.present?
        result = oauth_token.get('https://www.googleapis.com/calendar/v3/calendars/'+calendar_id+'/events?fields=items(summary,start,end)&maxResults=2500')

        data = JSON.parse(result.body)

        data['items'].each do |e|
          pattern = /(.+) - / #/^([\w]+)/
          matches = pattern.match(e['summary'])

          if matches.present? and matches[1].present?
            unless calendar[matches[1]].present?
              calendar[matches[1]] = []
            end

            calendar[matches[1]] << [e['start']['dateTime'].to_date,e['end']['dateTime'].to_date-1.day]
          end
        end
      end
    rescue
      calendar = {}
    end

    @calendar = calendar
  end

  def oauth_token
    @token ||= OAuth2::AccessToken.from_hash(oauth_client, JSON.parse(session[:oauth_token]))

    if !@token.present? or @token.expired?
      @token = @token.refresh!
      #session[:oauth_token] = @token.to_hash.to_json

      #session.delete(:oauth_token)
    end

    @token
  end

  def oauth_client
    @client ||= OAuth2::Client.new(Setting.plugin_redmine_cpm[:client_id], Setting.plugin_redmine_cpm[:client_secret],
      :site => 'https://accounts.google.com',
      :authorize_url => '/o/oauth2/auth',
      :token_url => '/o/oauth2/token',
      :access_type => 'offline',
      :approval_prompt => 'force')
  end

  def scopes
    'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.readonly'
  end


  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end
