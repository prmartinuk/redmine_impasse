class ImpasseExecutionBugsController < ApplicationController
  unloadable

  menu_item :impasse
  
  def create_bug
    execution_bug = Impasse::ExecutionBug.new(:execution_id => params[:execution_bug][:execution_id], :bug_id => params[:execution_bug][:issue_id])
    if execution_bug.save!
      respond_to do |format|
        format.json  { render :json => { :status => 'success' } }
      end
    else
      respond_to do |format|
        format.json  { render :json => { :status => 'success' } }
      end
    end
  end

end
