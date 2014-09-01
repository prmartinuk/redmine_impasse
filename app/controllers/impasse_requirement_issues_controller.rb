class ImpasseRequirementIssuesController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id, :authorize

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :projects
  include ImpasseRequirementIssuesHelper

  def index
    @versions = Impasse::Node.find_version(@project)
    setting = Impasse::Setting.find_by_project_id(@project.id)
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)

    if @query.valid?
      @limit = per_page_option

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new self, @issue_count, @limit, params['page']
      @offset ||= @issue_pages.current.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      @issue_count_by_group = @query.issue_count_by_group

      respond_to do |format|
        format.html { render :index, :layout => false }
        format.js { render :layout => false, :partial => 'impasse_common/render_issues', :locals => {:ctrl => "impasse_requirement_issues", :query => @query, :issue_pages => @issue_pages, :issue_count => @issue_count, :issues => @issues} }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def add_test_case
    ActiveRecord::Base.transaction do
      requirement_issue = Impasse::RequirementIssue.find_by_issue_id(params[:issue_id]) || Impasse::RequirementIssue.create(:issue_id => params[:issue_id])
      node = Impasse::Node.find(params[:test_case_id])
      if node.is_test_case?
        create_requirement_case(requirement_issue.id, node.id)
      else
        for test_case_node in node.find_with_children_test_case
          create_requirement_case(requirement_issue.id, test_case_node.id)
        end
      end

      render :json => { :status => 'success', :message => l(:notice_successful_create) }
    end
  end

  def remove_test_case
    ActiveRecord::Base.transaction do
      requirement_issue = Impasse::RequirementIssue.find(params[:id])
      requirement_cases = requirement_issue.requirement_cases.find(:first, :conditions => { :test_case_id => params[:test_case_id] })
      requirement_cases.destroy

      render :json => { :status => 'success', :message => l(:notice_successful_delete) }
    end
  end

  private
  def create_requirement_case(requirement_id, test_case_id) 
    Impasse::RequirementCase.find_by_requirement_id_and_test_case_id(requirement_id, test_case_id) || Impasse::RequirementCase.create(:requirement_id => requirement_id, :test_case_id => test_case_id)
  end

end
