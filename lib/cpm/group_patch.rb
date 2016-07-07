require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

module CPM
  module GroupPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will be reloaded in development

      end
    end

    module ClassMethods
      def not_allowed(ignore_blacklist = false)
        if ignore_blacklist
          [0]
        else
          if Setting.plugin_redmine_cpm['ignore_unselected_groups']
            Group.all.map(&:id) - Setting.plugin_redmine_cpm['ignored_groups'].map(&:to_i) || [0]
          else
            Setting.plugin_redmine_cpm['ignored_groups'] || [0]
          end
        end
      end

      def allowed(ignore_blacklist = false)
        where("id NOT IN (?)", not_allowed(ignore_blacklist))
      end
    end
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'group'
    Group.send(:include, CPM::GroupPatch)
  end
else
  Dispatcher.to_prepare do
    require_dependency 'group'
    Group.send(:include, CPM::GroupPatch)
  end
end
