module CpmAppHelper
	# Controls CPM tab selected
	def selected_tab_class(tab)
    'selected' if case tab
                  when 'reports'
                    params[:controller] == 'cpm_reports' and params[:action] == 'reports'
                  when 'show'
                    params[:controller] == 'cpm_management' and params[:action] == 'show'
               end
	end

	def even_odd(row)
		if row%2==0 
			"even"
		else
			"odd"
		end 
	end
end