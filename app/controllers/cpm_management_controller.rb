﻿class CpmManagementController < ApplicationController
  unloadable

  before_filter :authorize_global
  before_filter :set_menu_item
  before_filter :oauth_authentication, :only => :show, :unless => :oauth_token?

  helper :cpm_management

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
    if Setting.plugin_redmine_cpm[:google_calendar].present?
      get_calendar
    end
    # set black list arrays to empty if 'ignore_black_lists' filter is activated
    if !params['ignore_black_lists'].present?
      ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]
      ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    else
      ignored_users = [0]
      ignored_projects =[0]
    end

    # users and projects to show in planning table
    @users = []
    @projects = []

    # getting @projects array
    # add projects specified by project manager filter
    if params[:project_manager].present?
      project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];
      if project_manager_role.present?
        @projects += MemberRole.find(:all, :include => :member, :conditions => ['members.user_id IN (?) AND role_id = ?', params[:project_manager].join(','), project_manager_role]).collect{|mr| mr.member.project_id}
      end
    end

    # exclude ignored projects
    @projects = @projects.uniq.reject{|p| ignored_projects.include?(p.to_s)}

    # filter projects if custom field filters are specified
    if params[:custom_field].present?
      filtered_projects = []

      # if there are no projects specified and there are field filters specified, get all not ignored projects by default
      if @projects.empty?
        @projects = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| p.id}
      end
      
      # for each project available will check if match with all custom field filters activated
      @projects.each do |p|
        filter = false
        params[:custom_field].each do |cf,v|
          if !filter
            filter = CustomValue.where("customized_type = ? AND customized_id = ? AND custom_field_id = ? AND value IN (?)","Project",p,cf,v.map{|e| e}) == []
          end
        end
        if !filter
          filtered_projects << p
        end
      end

      @projects = filtered_projects
    end

    # add projects specified by project filter
    if params[:projects].present?
      @projects += params[:projects]
      @projects.uniq
    end

    # if @projects are empty, get all not ignored projects by default
    if @projects.empty? and !params[:custom_field].present? and !params[:project_manager].present?
      #flash.now[:warning] = l(:'cpm.msg_projects_not_found')
      @projects = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| p.id}
    end

    if !@projects.empty?
      # getting @users array
      # add users specified by users filter
      if params[:users].present?
        @users += User.where("id IN (?)", params[:users])
      end

      # add users specified by groups filter
      if params[:groups].present?
        @users += Group.where("id IN (?)", params[:groups]).collect{|g| g.users.reject{|u| ignored_users.include?((u.id).to_s)}}.flatten
      end

      # reorder and unify users
      @users = @users.uniq.sort_by{|u| u.login}

      # if there are no users selected, get them based on projects selected
      if !@projects.blank? and @users.blank?
        projects = Project.where("id IN ("+@projects.join(',')+")")

        # get users who are project members
        members = projects.collect{|p| p.members.collect{|m| m.user_id}}.flatten
        # get users who have time entries in projects
        time_entries = projects.collect{|p| p.time_entries.collect{|te| te.user_id}}.flatten

        @users = User.where("id IN (?)", (members+time_entries).uniq).reject{|u| ignored_users.include?((u.id).to_s)}.sort_by{|u| u.login}
      # if there are no projects selected, get them based on users selected
      #elsif @projects.blank? and !@users.blank?
        #members = Project.joins(:memberships).where("members.user_id IN (?)",@users)
        #time_entries = Project.joins(:time_entries).where("time_entries.user_id IN (?)",@users)
        #@projects = Project.where("id IN (?)", (members+time_entries).uniq).reject{|p| ignored_projects.include?((p.id).to_s)}.sort_by{|p| p.name}.collect{|p| p.id}
      end
    end

    # set time_unit and time_unit_num default values
    @time_unit = params[:time_unit] || 'week'
    @time_unit_num = (params[:time_unit_num] || 12).to_i

    if @calendar.present?
      absence_project_id = Setting.plugin_redmine_cpm['absence_project']
      if absence_project_id.present?
        holidays = {}
        @users.each do |user|
          holidays[user.id] = []
          if @calendar[user.login].present?
            @calendar[user.login].each do |cpm|
              holidays[user.id] << CpmUserCapacity.new(user_id: user.id, project_id: absence_project_id, capacity: 100, from_date: cpm[0], to_date: cpm[1])
            end
          end
        end
      end
    end

    @capacities = {}
    @users.each do |user|
      @capacities[user.id] = @time_unit_num.times.collect{|i| {'value' => 0.0, 'tooltip' => ""}}
      capacities = CpmUserCapacity.where('user_id = ? AND project_id IN(?)',user.id, @projects)
      capacities += holidays[user.id] if holidays.present?

      capacities.each do |capacity|
        @time_unit_num.times do |i|
          start_day = CPM::CpmDate.get_start_date(@time_unit,i)
          end_day = CPM::CpmDate.get_due_date(@time_unit,i)
          @capacities[user.id][i]['value'] += capacity.get_relative(start_day, end_day)
          @capacities[user.id][i]['tooltip'] += capacity.get_tooltip(start_day, end_day)
        end
      end
    end
    
    if request.xhr?
      render "cpm_management/_planning" ,layout: false
    end
  end

  # Capacity edit form
  def edit_form
    # set projects black list array to empty if 'ignore_black_lists' filter is activated
    if !params['ignore_black_lists'].present?
      ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    else
      ignored_projects =[0]
    end

    user = User.find_by_id(params[:user_id])
    projects = params[:projects]
    
    @from_date = Date.strptime(params[:from_date], "%d/%m/%y")
    @to_date = Date.strptime(params[:to_date], "%d/%m/%y")

    # load pojects options
    @projects_for_selection = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| [p.name,p.id]}
    
    if projects.present?
      @default_project = projects[0]
    else
      @default_project = nil
    end

    @capacities = user.get_range_capacities(@from_date,@to_date,projects)

    @capacities.each do |c|
      if !c.check_capacity(ignored_projects)
        flash[:warning] = l(:"cpm.msg_capacity_higher_than_100")
      end
    end

    @cpm_user_capacity = CpmUserCapacity.new
    @cpm_user_capacity.user_id = params[:user_id]

    render layout: false
  end

# Search filters
  def get_filter_users
    ignored_users = Setting.plugin_redmine_cpm['ignored_users'] || [0]

    if params['show_banned_users'].present?
      ignored_users = [0]
    end

    @users_selected = []
    if params['users'].present?
      @users_selected = params['users']
    end

    @users_options = User.where("id NOT IN(?)", ignored_users).sort_by{|u| u.login}.collect{|u| [u.login, (u.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/users', :layout => false, :locals => { :options => @users_options }) }
    end
  end

  def get_filter_groups
    ignored_groups = Setting.plugin_redmine_cpm['ignored_groups'] || [0]
    if params['show_banned_groups'].present?
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
    ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    if params['show_banned_projects'].present?
      ignored_projects = [0]
    end

    @projects_selected = []
    if params['projects'].present?
      @projects_selected = params['projects']
    end

    @projects_options = Project.where("id NOT IN (?)", ignored_projects).sort_by{|p| p.name}.collect{|p| [CGI::escapeHTML(p.name), (p.id).to_s]}

    if request.xhr?
      render :json => { :filter => render_to_string(:partial => 'cpm_management/filters/projects', :layout => false, :locals => { :options => @projects_options }) }
    end
  end

  def get_filter_project_manager
    ignored_projects = Setting.plugin_redmine_cpm['ignored_projects'] || [0]
    project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];

    role_pm = Role.find_by_id(project_manager_role)

    users = []
    Project.where("id NOT IN (?)", ignored_projects).collect{|p|
      project_manager = p.users_by_role[role_pm]
      if project_manager.present?
        project_manager.each do |pm|
          users << pm
        end
      end
    }

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
    #last_year = (Time.now.to_datetime-1.year).rfc3339
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
          
          calendar[matches[1]] << [e['start']['dateTime'].to_time+1.hour,e['end']['dateTime'].to_time+1.hour-1.day]
        end
      end
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
