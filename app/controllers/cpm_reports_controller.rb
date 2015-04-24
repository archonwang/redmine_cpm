class CpmReportsController < ApplicationController
  unloadable

  #before_filter :authorize_global, :only => [:show]
  before_filter :set_menu_item

  helper :cpm_app

  # Main view for reports generation
  def reports
    # Load report types
    @report_types = [["","default"]]

    if Setting.plugin_redmine_cpm['project_manager_role'].present?
      @report_types << [l(:"cpm.label_project_manager_role"), "project_manager"]
      @report_types << [l(:"label_user"), "user"]
    end

    if params[:report_type].present?
      @report = {}
      @report[:name] = params[:report_type]
      @report[:partial_result] = 'cpm_reports/reports/'+params[:report_type]
      @report[:partial_options] = 'cpm_reports/report_options/'+params[:report_type]
      @report[:options] = params[:report_options]

      # Get data for report generation
      @result = CPM::Reports.get_report(@report[:name], @report)

      # If it's an export request, load export headers
      if params[:format].present?
        @format = params[:format]
        export
      # If it isn't an export request, load options data
      else
        eval("get_report_options_"+@report[:name])
      end
    end
  end

  # Show project manager reports options data
  def get_report_options_project_manager
    project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];

    @report_options = User.get_by_role(project_manager_role).collect{|u| [u.login, (u.id).to_s]}.sort

    # If it's an AJAX request, send options partial
    if request.xhr?
      render :json => { :options => render_to_string(:partial => 'cpm_reports/report_options/project_manager', :layout => false )}
    end
  end

  # Show user reports options data
  def get_report_options_user
    @report_options = User.allowed.collect{|u| [u.login, (u.id).to_s]}.sort

    # If it's an AJAX request, send options partial
    if request.xhr?
      render :json => { :options => render_to_string(:partial => 'cpm_reports/report_options/user', :layout => false )}
    end
  end

  # Add headers to generate the file to export with the proper file extension
  def export
    headers['Content-Type'] = "text/plain" #"application/vnd.ms-excel"
    headers['Content-Disposition'] = 'attachment; filename="'+@report[:name]+'_planning_'+Date.today.strftime("%Y%m%d")+'.'+@format+'"'
    headers['Cache-Control'] = ''

    render 'cpm_reports/reports/_'+@report[:name], :layout => false
  end

  private
  def set_menu_item
    self.class.menu_item params['action'].to_sym
  end
end