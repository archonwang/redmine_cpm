module CPM
  class Filters
    unloadable

    def self.projects(projects)
    	projects
    end

    def self.users(users)
    	User.where("id IN (?)", users)
    end

    def self.groups(groups, ignore_blacklist)
    	Group.where("id IN (?)", groups).collect{|g| g.users.reject{|u| User.not_allowed(ignore_blacklist).include?((u.id).to_s)}}.flatten
    end

    def self.project_manager(ids)
    	project_manager_role = Setting.plugin_redmine_cpm['project_manager_role']
      if project_manager_role.present?
        projects = MemberRole.find(:all, :include => :member, :conditions => ['members.user_id IN ('+ids.to_a.join(',')+') AND role_id = ?', project_manager_role]).collect{|mr| mr.member.project_id}
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

	end
end