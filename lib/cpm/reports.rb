module CPM
  class Reports
    unloadable

    def self.get_report(type, data)
      case type
      when 'project_manager'
        get_report_project_manager(data)
      when 'user'
        get_report_users(data)
      else
        []
      end
    end

    def self.get_report_project_manager(data)
      project_manager_role = Setting.plugin_redmine_cpm['project_manager_role'];
      result = []

      if data[:options].present?
        project_managers = data[:options][:project_managers]
        project_managers = User.find(project_managers).sort_by{|u| u.login}
      else
        project_managers = User.get_by_role(project_manager_role).sort_by{|u| u.login}
      end

      i = 0
      project_managers.each do |pm|
        result[i] = {}
  
        result[i][:name] = pm.login
        result[i][:projects] = []
        j = 0
  
        projects = Project.find(:all, :include => [:memberships, {:memberships => :member_roles}], :conditions => ["members.user_id = ? AND member_roles.role_id = ? AND projects.id NOT IN (?)", pm.id, project_manager_role, Project.not_allowed])
  
        projects.each do |p|
          result[i][:projects][j] = {}
          result[i][:projects][j][:name] = p.name
          if Setting.plugin_redmine_cpm['plugin_cmi'].present? and p.cmi_project_info.present? and p.cmi_project_info.scheduled_finish_date.present?
            result[i][:projects][j][:end] = '('+p.cmi_project_info.scheduled_finish_date.strftime("%d/%m/%Y")+')' #p.created_on.strftime("%d/%m/%Y")
          else
            result[i][:projects][j][:end] = '' #p.created_on.strftime("%d/%m/%Y")
          end
          result[i][:projects][j][:members] = []
          k = 0
  
  
          users = User.find(:all, :include => [{:cpm_capacities => :project}], :conditions => ["projects.id = ?", p.id])
          users.each do |u|
            
            result[i][:projects][j][:members][k] = {}
            result[i][:projects][j][:members][k][:name] = u.login
            result[i][:projects][j][:members][k][:capacities] = []
            l = 0
            capacities = CpmUserCapacity.find(:all, :conditions => ["user_id = ? AND project_id = ? AND to_date >= ?", u.id, p.id, Date.today])
            capacities.each do |c|
              result[i][:projects][j][:members][k][:capacities][l] = {}
              result[i][:projects][j][:members][k][:capacities][l][:capacity] = c[:capacity]
              result[i][:projects][j][:members][k][:capacities][l][:from_date] = c[:from_date].strftime("%d/%m/%Y")
              result[i][:projects][j][:members][k][:capacities][l][:to_date] = c[:to_date].strftime("%d/%m/%Y")
              l = l + 1
            end
            
            # If there are no capacities, remove member row
            if l != 0
              k = k + 1
            else
              result[i][:projects][j][:members].pop #[k] = nil
            end
          end
  
          # If there are no members, remove project table
          if k != 0
            j = j + 1
          else
            result[i][:projects].pop #[j] = nil
          end
        end
  
        # If there are no projects, remove project manager
        #if j != 0
          i = i + 1
        #else 
        #  result.pop #[i] = nil
        #end
      end

      result
    end

    def self.get_report_users(data)
      pm_role = Role.find(Setting.plugin_redmine_cpm['project_manager_role']);
      result = []

      if data[:options].present?
        users = data[:options][:users]
        users = User.find(users).sort_by{|u| u.login}
      else
        users = User.allowed.sort_by{|u| u.login} #.collect{|u| u.id}
      end
  
      i = 0
      users.each do |u|
        result[i] = {}
  
        result[i][:name] = u.login
        result[i][:project_managers] = {}

        projects = Project.find(:all, :include => [{:capacities => :user}], :conditions => ["users.id = ?", u.id])

        projects.each do |p|
          project = {}

          project[:name] = p.name
          if Setting.plugin_redmine_cpm['plugin_cmi'].present? and p.cmi_project_info.present? and p.cmi_project_info.scheduled_finish_date.present?
            project[:end] = '('+p.cmi_project_info.scheduled_finish_date.strftime("%d/%m/%Y")+')' #p.created_on.strftime("%d/%m/%Y")
          else
            project[:end] = '' #p.created_on.strftime("%d/%m/%Y")
          end
          project[:capacities] = []

          l = 0
          capacities = CpmUserCapacity.find(:all, :conditions => ["user_id = ? AND project_id = ? AND to_date >= ?", u.id, p.id, Date.today])
          capacities.each do |c|
            project[:capacities][l] = {}
            project[:capacities][l][:capacity] = c[:capacity]
            project[:capacities][l][:from_date] = c[:from_date].strftime("%d/%m/%Y")
            project[:capacities][l][:to_date] = c[:to_date].strftime("%d/%m/%Y")
            l = l + 1
          end

          if l != 0
             pm_index = p.users_by_role[pm_role[0]].collect{|pm| pm.login}.sort.join(', ')

            if !result[i][:project_managers][pm_index].present? 
              result[i][:project_managers][pm_index] = []
            end

            result[i][:project_managers][pm_index] << project
          end
        end

        #if result[i][:project_managers].present?
          i = i + 1
        #else
        #  result.pop
        #end
      end

      result
    end

	end
end