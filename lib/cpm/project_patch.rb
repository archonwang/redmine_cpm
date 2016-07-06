require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

module CPM
  unloadable
  module ProjectPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development

        has_many :capacities, :class_name => 'CpmUserCapacity', :dependent => :destroy
      end
    end

    module ClassMethods
      def not_allowed(ignore_blacklist = false)
        if ignore_blacklist
          [0]
        else
          Setting.plugin_redmine_cpm['ignored_projects'] || [0]
        end
      end

      def allowed(ignore_blacklist = false)
        active.where("id NOT IN (?)", not_allowed(ignore_blacklist))
      end
    end

    module InstanceMethods
    end
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'project'
    Project.send(:include, CPM::ProjectPatch)
  end
else
  Dispatcher.to_prepare do
    require_dependency 'project'
    Project.send(:include, CPM::ProjectPatch)
  end
end
