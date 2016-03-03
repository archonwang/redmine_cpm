# Plugin's routes
RedmineApp::Application.routes.draw do
	get '/cpm_management/:action' => 'cpm_management'
	match '/cpm_user_capacity/:action' => 'cpm_user_capacity', via: [:get, :post]
	match '/cpm_management/edit_form/:user_id' => 'cpm_management#edit_form', via: [:get, :post]
	match '/cpm_user_capacity/edit/:id' => 'cpm_user_capacity#edit', via: [:post, :put, :patch]
	match '/cpm_user_capacity/delete/:id' => 'cpm_user_capacity#delete', via: [:delete]
	match '/cpm_management/get_filter_custom_field/:custom_field_id' => 'cpm_management#get_filter_custom_field', via: [:get]
	get 'oauth2callback_cpm', :to => 'cpm_management#oauth_callback', :as => 'oauth_callback'

	match '/cpm_reports/:action' => 'cpm_reports', via: [:get, :post]
	match '/cpm_reports/reports.:format' => 'cpm_reports#reports', via: [:get, :post]
end
