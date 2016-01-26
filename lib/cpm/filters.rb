module CPM
  class Filters
    unloadable

    def self.projects(projects)
    	projects
    end

    def self.users(users)
      users
    end

    def self.groups(groups, users) #, ignore_blacklist)
      User.includes(:groups).where("groups_users_join.group_id IN (?) AND users.id IN (?)", groups, users)
    end

    def self.project_manager(ids, projects)
    	project_manager_role = Setting.plugin_redmine_cpm['project_manager_role']
      if project_manager_role.present?
        projects = MemberRole.joins(:member).where('members.user_id IN ('+ids.to_a.join(',')+') AND members.project_id IN (?) AND role_id = ?', projects, project_manager_role).collect{|mr| mr.member.project_id}
      end

      projects
    end

    def self.custom_field(filters, projects)
    	filtered_projects = []
      
      # for each project available will check if match with all custom field filters activated
      projects.each do |p|
        filter = false
        filters.each do |cf,v|
          if !filter
            filter = CustomValue.where("customized_type = ? AND customized_id = ? AND custom_field_id = ? AND value IN (?)","Project",p,cf,v.map{|e| e}) == []
          end
        end
        if !filter
          filtered_projects << p
        end
      end

      filtered_projects
    end

    def self.time_unit
    end

    def self.time_unit_num
    end

    def self.knowledges(knowledges, users)
      User.with_knowledges(knowledges,users).collect{|u| u.id}
    end

	end
end