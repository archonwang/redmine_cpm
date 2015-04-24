require 'redmine/menu_manager'

module CPM
  module MenuHelperPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :render_main_menu, :cpm_menu
        alias_method_chain :display_main_menu?, :cpm_menu
      end
    end

    module InstanceMethods
      # Adds a rates tab to the user administration page
      def render_main_menu_with_cpm_menu(project)
        # Core defined data
        if ['cpm_management', 'cpm_reports'].include?(params[:controller]) 
          render_menu :cpm_menu
        else
          render_main_menu_without_cpm_menu project
        end
      end
      def display_main_menu_with_cpm_menu?(project)
        # Core defined data
        if ['cpm_management', 'cpm_reports'].include?(params[:controller])
          return true
        else
          display_main_menu_without_cpm_menu? project
        end
      end
    end
  end
end

Redmine::MenuManager::MenuHelper.send :include, CPM::MenuHelperPatch
