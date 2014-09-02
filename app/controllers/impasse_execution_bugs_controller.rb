class ImpasseExecutionBugsController < ApplicationController
  unloadable

  menu_item :impasse
  
  def create_bug
    execution_bug = Impasse::ExecutionBug.find_or_initialize_by_execution_id_and_bug_id(:execution_id => params[:execution_bug][:execution_id], :bug_id => params[:execution_bug][:issue_id])
    if execution_bug.save!
      respond_to do |format|
        format.json  { render :json => { :status => 'success' } }
      end
    else
      respond_to do |format|
        format.json  { render :json => { :status => 'error' } }
      end
    end
  end

end
