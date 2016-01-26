class CpmUserCapacityController < ApplicationController
  unloadable

  # Add new capacity to an user for a project
  def new
    #data = params[:cpm_user_capacity]

  	@cpm_user_capacity = CpmUserCapacity.new(cpm_user_capacity_params)

  	if @cpm_user_capacity.save
  		flash[:notice] = l(:"cpm.msg_save_success")  
    else
  		flash[:error] = @cpm_user_capacity.get_error_message
    end

    redirect_to  controller:'cpm_management', action:'edit_form', 
                    user_id:@cpm_user_capacity.user_id, 
                    from_date:params[:start_date], 
                    to_date:params[:due_date], 
                    projects:params[:projects],
                    ignore_black_lists:params[:ignore_black_lists]
  end

  # Edit a capacity for an user
  def edit
    cpm = CpmUserCapacity.find_by_id(params[:id])
    #data = params[:cpm_user_capacity]
    #data[:project_id] = data[:project_id].to_i
    
    params[:cpm_user_capacity][:project_id] = params[:cpm_user_capacity][:project_id].to_i

    if cpm.update_attributes(cpm_user_capacity_params)
      flash[:notice] = l(:"cpm.msg_edit_success")
    else
      flash[:error] = cpm.get_error_message
    end

    redirect_to controller:'cpm_management' ,action:'edit_form', 
                user_id:cpm.user_id, 
                from_date:params[:start_date], 
                to_date:params[:due_date], 
                projects:params[:projects],
                ignore_black_lists:params[:ignore_black_lists]
  end

  def delete
    cpm = CpmUserCapacity.find_by_id(params[:id])

    if cpm.destroy
      flash[:notice] = l(:"cpm.msg_delete_success")
    else
      flash[:error] = cpm.get_error_message
    end

    redirect_to controller:'cpm_management', action:'edit_form', 
                user_id:cpm.user_id, 
                from_date:params[:start_date], 
                to_date:params[:due_date], 
                projects:params[:projects],
                ignore_black_lists:params[:ignore_black_lists], 
                status: 303 # To prevent redirect with 'delete' method. See: http://api.rubyonrails.org/classes/ActionController/Redirecting.html
  end

  private
  def cpm_user_capacity_params
    params.require(:cpm_user_capacity).permit(:capacity, :from_date, :to_date, :user_id, :project_id, :editor_id)
  end
end