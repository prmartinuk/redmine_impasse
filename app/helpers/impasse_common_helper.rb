# encoding: utf-8

module ImpasseCommonHelper
  unloadable

  TABS = [{:name => 'basic', :url => { :controller => :impasse_test_plans, :action => :show}, :label => :label_general},
          {:name => 'tc_assign', :url => { :controller => :impasse_test_plans, :action => :tc_assign},:label => :label_tc_assign},
          {:name => 'user_assign', :url => { :controller => :impasse_test_plans, :action => :user_assign}, :label => :label_user_assign},
          {:name => 'execution', :url => { :controller => :impasse_executions, :action => :index}, :label => :label_execution},
          {:name => 'statistics', :url => { :controller => :impasse_test_plans, :action => :statistics}, :label => :label_statistics}
         ]

  def render_impasse_tabs
    render :partial => 'impasse_common/impasse_tabs', :locals => { :tabs => TABS }
  end

  def impasse_breadcrumb(*args)
    elements = args.flatten
    elements.any? ? content_tag('p', args.join(" \xc2\xbb ").html_safe, :class => 'breadcrumb') : nil
  end

  def impasse_pagination_links_full(*args)
    pagination_links_each(*args) do |text, parameters, options|
      options ||= {}
      options = options.merge({ :id => "impasse_pagination_link", :params => parameters})
      if block_given?
        yield text, parameters, options
      else
        link_to text, params.merge(parameters), options
      end
    end
  end

  def impasse_retrieve_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = Impasse::ImpasseIssueQuery.find(params[:query_id], :conditions => cond)
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = Impasse::ImpasseIssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = Impasse::ImpasseIssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= Impasse::ImpasseIssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end

end
