class ImpasseTestPlansController < ApplicationController

  helper :projects
  include ProjectsHelper
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :custom_fields
  include CustomFieldsHelper
  include ImpasseTestPlansHelper

  menu_item :impasse
  before_filter :find_project_by_project_id
  accept_api_auth :index, :show, :edit, :destroy, :new, :update

  def index
    @test_plans_by_version, @versions = Impasse::TestPlan.find_all_by_version(@project, params[:completed])
  end

  def show
    @test_plan = Impasse::TestPlan.find(params[:id])
    @setting = Impasse::Setting.find_by_project_id(@project) || Impasse::Setting.create(:project_id => @project.id)
  end

  def new
    @versions = @project.shared_versions.open
    impasse_retrieve_query
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
    end
    @test_plan = Impasse::TestPlan.new(params[:test_plan])
    respond_to do |format|
      format.html {}
      format.js { render :partial => 'impasse_common/render_issues', :locals => {:ctrl => "impasse_test_plans", :query => @query, :issue_pages => @issue_pages, :issue_count => @issue_count, :issues => @issues} }
    end
  end

  def create
    if request.post?
      @versions = Impasse::Node.find_version(@project)
      impasse_retrieve_query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      @query.update_attributes(:name => params[:test_plan][:name], :is_public => true)
      @query.save
      params[:test_plan] ||= {}
      if 'v'.in? params
        if "fixed_version_id".in? params['v']
          if params['v']['fixed_version_id'].length == 1
            params[:test_plan][:version_id] = params['v']['fixed_version_id'][0].to_i
          end
        end
      end
      params[:test_plan][:query_id] = @query.id
      @test_plan = Impasse::TestPlan.new(params[:test_plan])
      if @test_plan.save
        redirect_to :action => 'show', :id => @test_plan.id
      else
        render :new
      end
    else
      redirect_to :action => :new
    end
  end

  def edit
    @test_plan = Impasse::TestPlan.find(params[:id])
    unless 'set_filter'.in? params and 'f'.in? params and 'v'.in? params
      unless @test_plan.query.nil?
        params[:query_id] = @test_plan.query_id 
      end
    end
    @versions = Impasse::Node.find_version(@project)
    impasse_retrieve_query
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
    end
    respond_to do |format|
      format.html {}
      format.js { render :partial => 'impasse_common/render_issues', :locals => {:ctrl => "impasse_test_plans", :query => @query, :issue_pages => @issue_pages, :issue_count => @issue_count, :issues => @issues}}
    end
  end

  def update
    if request.put?
      @test_plan = Impasse::TestPlan.find(params[:id])
      unless 'set_filter'.in? params and 'f'.in? params and 'v'.in? params
        unless @test_plan.query.nil?
          params[:query_id] = @test_plan.query_id 
        end
      end
      @versions = Impasse::Node.find_version(@project)
      impasse_retrieve_query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      if @query.id.nil?
        unless @test_plan.query.nil?
          @test_plan.query.destroy
        end
        @query.update_attributes(:name => params[:test_plan][:name], :is_public => true)
        @query.save
      end
      params[:test_plan][:query_id] = @query.id
      params[:test_plan] ||= {}
      if 'v'.in? params
        if "fixed_version_id".in? params['v']
          if params['v']['fixed_version_id'].length == 1
            params[:test_plan][:version_id] = params['v']['fixed_version_id'][0].to_i
          end
          if params['v']['fixed_version_id'].length > 1
            @test_plan.version = nil
          end
        end
      end
      @test_plan.attributes = params[:test_plan]
      if @test_plan.save
        flash[:notice] = l(:notice_successful_update)
        redirect_to :action => :show, :project_id => @project, :id => @test_plan
      else
        render :edit
      end
    else
      redirect_to :action => :edit, :project_id => @project, :id => params[:id]
    end
  end

  def destroy
    @test_plan = Impasse::TestPlan.find(params[:id])
    if request.post? and @test_plan.destroy
      @test_plan.query.destroy
      flash[:notice] = l(:notice_successful_delete)
      redirect_to :action => :index, :project_id => @project
    end
  end

  def add_test_case
    if params.include? :test_case_ids
      nodes = Impasse::Node.where("id in (?)", params[:test_case_ids])
      ActiveRecord::Base.transaction do
        for node in nodes
          test_case_ids = []
          if node.is_test_suite?
            test_case_ids.concat node.find_with_children_test_case.collect{|n| n.id}
          else
            test_case_ids << node.id
          end

          for test_case_id in test_case_ids
              test_plan_case = Impasse::TestPlanCase.find_or_create_by_test_case_id_and_test_plan_id(
                                                                                      :test_case_id => test_case_id,
                                                                                      :test_plan_id => params[:test_plan_id],
                                                                                      :node_order => 0)
          end
        end
      end
    end
    render :json => { :status => 'success', :message => l(:notice_successful_create) }
  end

  def copy
    @test_plan = Impasse::TestPlan.find(params[:id])
    @test_plan.attributes = params[:test_plan]
    if request.post? or request.put?
      ActiveRecord::Base.transaction do
        new_test_plan = @test_plan.dup
        new_test_plan.save!

        test_plan_cases = Impasse::TestPlanCase.find_all_by_test_plan_id(params[:id])
        for test_plan_case in test_plan_cases
          Impasse::TestPlanCase.create(:test_plan_id => new_test_plan.id, :test_case_id => test_plan_case.test_case_id)
        end
        flash[:notice] = l(:notice_successful_update)
        redirect_to :action => :show, :project_id => @project, :id => new_test_plan
      end
    end
    @versions = Impasse::Node.find_version(@project)
  end

  def tc_assign
    params[:tab] = 'tc_assign'
    @versions = Impasse::Node.find_version(@project)
    @test_plan = Impasse::TestPlan.find(params[:id])
  end

  def user_assign
    params[:tab] = 'user_assign'
    @versions = Impasse::Node.find_version(@project)
    @test_plan = Impasse::TestPlan.find(params[:id])
  end

  def statistics
    @test_plan = Impasse::TestPlan.find(params[:id])
    params[:tab] = 'statistics'
    if params.include? :type
      @statistics = Impasse::Statistics.__send__("summary_#{params[:type]}", @test_plan.id)
    else
      params[:type] = "default"
      @statistics = Impasse::Statistics.summary_default(@test_plan.id)
    end

    respond_to do |format|
      if request.xhr?
        format.html { render :partial => "impasse_test_plans/statistics/#{params[:type]}" }
      else
        format.html
      end
      format.json_impasse { render :json => @statistics }
    end
  end

  def remove_test_case
    Impasse::TestPlanCase.delete_cascade!(params[:test_plan_id], params[:test_case_id])
    render :json => { :status => 'success', :message => l(:notice_successful_delete) }
  end

  def autocomplete
    @users = @project.users.like(params[:q]).all(:limit => 100)
    render :layout => false
  end
  
  def coverage
    @versions = Impasse::Node.find_version(@project)
    @version = params[:id]
    render :layout => true
  end
  
  def coverage_case
    @versions = Impasse::Node.find_version(@project)
    @case = params[:id]
    render :layout => true
  end
end
