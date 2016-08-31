module CPM
  class Reports
    DEFAULT_REPORTS = ['users','projects']

    def self.generate_report(data)
      case data[:type]
      when 'projects'
        generate_report_projects(data[:selected])
      when 'users'
        generate_report_users(data[:selected])
      else
        {}
      end
    end

    def self.generate_report_users(selected_users)
      result = {
        :headers => [:project, :capacity, :from_date, :to_date],
        :data => {}
      }

      if selected_users.present?
        users = User.find(selected_users).sort_by(&:login)
      else
        users = User.allowed.sort_by(&:login)
      end

      users.each do |user|
        result[:data][user.login] = {}

        if user.cpm_capacities.current.allowed.present?
          user_capacities = user.cpm_capacities.current.map{|c| c.slice(:project_id, :capacity, :from_date, :to_date)}.group_by{|c| Project.find(c["project_id"]).name}

          result[:data][user.login] = user_capacities if user_capacities.present?  
        end
      end

      result
    end

    def self.generate_report_projects(selected_projects)
      result = {
        :headers => [:user, :capacity, :from_date, :to_date],
        :data => {}
      }

      if selected_projects.present?
        projects = Project.find(selected_projects).sort_by(&:name)
      else
        projects = Project.allowed.sort_by(&:name)
      end

      projects.each do |project|
        result[:data][project.name] = {}

        if project.capacities.current.allowed.present?
          project_capacities = project.capacities.current.map{|c| c.slice(:user_id, :capacity, :from_date, :to_date)}.group_by{|c| User.find(c["user_id"]).login}

          result[:data][project.name] = project_capacities if project_capacities.present?  
        end
      end

      result
    end
	end
end
