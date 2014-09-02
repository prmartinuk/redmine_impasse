class ImpasseTestCaseController < ApplicationController

  helper :attachments
  include AttachmentsHelper  
  helper :custom_fields
  include CustomFieldsHelper

  menu_item :impasse
  before_filter :find_project
  before_filter :get_settings, :only => [:index, :show, :new, :create, :destroy, :edit, :update]
  accept_api_auth :index, :show, :create, :update, :destroy, :new

  REL = {
    1 => "test_project",
    2 => "test_suite",
    3 => "test_case"
  }

  def index
    if User.current.allowed_to?(:move_issues, @project)
      @allowed_projects = Issue.allowed_target_projects_on_move
      @allowed_projects.delete_if{|project| @project.id == project.id }
    end
  end

  def list
    if params[:node_id].to_i == -1
      root = Impasse::Node.find_by_name_and_node_type_id(@project.identifier, 1)
      @nodes = root.find_children(params[:test_plan_id], params[:filters] || {})
      root.name = get_root_name(params[:test_plan_id])
      @nodes.unshift(root)
    else
      root = Impasse::Node.find(params[:node_id])
      @nodes = root.find_children(params[:test_plan_id], params[:filters] || {})
    end
    jstree_nodes = convert(@nodes, params[:prefix])
    render :json => jstree_nodes
  end
  
  def show
    @node = Impasse::Node.find(params[:id])
    @test_case = @node.test_case
    render :layout => false
  end

  def new
    @node = Impasse::Node.new(params[:node])
    @test_case = Impasse::TestCase.new(params[:test_case])
  end

  def create
    @node = Impasse::Node.new(params[:node])
    @test_case = Impasse::TestCase.new(params[:test_case])
    @test_case.save_attachments(params[:attachments] || (params[:test_case] && params[:test_case][:uploads]))
    @node.node_type_id = 3
    if @node.parent_id.nil?
      parent = Impasse::Node.find_by_name_and_node_type_id(@project.identifier, 1)
      @node.parent_id = parent.id
    end
    @node.node_order = Impasse::Node.where(:parent_id => @node.parent_id).map(&:node_order).max.to_i + 1
    begin
      success = false
      ActiveRecord::Base.transaction do
        success = save_node(@node)
        Impasse::Node.update_order_lft(@node)
        success = @node.save_keywords!(params[:node_keywords]) && success
        @test_case.id = @node.id
        success = @test_case.save! && success
        if params.include? :test_steps
          @test_steps = []
          sorted_params = Hash[params[:test_steps].map{|x, y| [y["step_number"].to_i, y]}.sort]
          sorted_params.each do |i, ts|
            ts.delete("id")
            test_step = Impasse::TestStep.new(ts)
            if test_step.valid?
              @test_steps << test_step
            end
          end
          success = @test_case.test_steps.replace(@test_steps) && success
        end
      end
      if success
        render_attachment_warning_if_needed(@test_case)
        flash[:notice] = l(:notice_successful_create)
        redirect_to :controller => :impasse_test_case, :action => :index, :anchor => "testcase-#{@node.id}"
      end
    rescue ActiveRecord::ActiveRecordError => e
      errors = []
      errors.concat(@node.errors.full_messages).concat(@test_case.errors.full_messages)
      if @test_steps
        @test_steps.each do |test_step|
          test_step.errors.full_messages.each do |msg|
            errors << "##{test_step.step_number} #{msg}"
          end
        end
      end
      flash.now[:error] = errors.join("<br>")
      render :new
    end
  end

  def edit
    @node = Impasse::Node.find(params[:id])
    @test_case = @node.test_case
  end

  def update
    @node = Impasse::Node.find(params[:id])
    @test_case = @node.test_case
    @test_case.save_attachments(params[:attachments] || (params[:test_case] && params[:test_case][:uploads]))
    @test_case.attributes = params[:test_case]
    @node.attributes = params[:node]
    begin
      success = false
      ActiveRecord::Base.transaction do
        success = save_node(@node)
        Impasse::Node.update_order_lft(@node)
        success = @node.save_keywords!(params[:node_keywords]) && success
        success = @test_case.save! && success

        if params.include? :test_steps
          @test_steps = []
          sorted_params = Hash[params[:test_steps].map{|x, y| [y["step_number"].to_i, y]}.sort]
          sorted_params.each do |i, ts|
            ts.delete("id")
            test_step = Impasse::TestStep.new(ts)
            if test_step.valid?
              @test_steps << test_step
            end
          end
          success = @test_case.test_steps.replace(@test_steps) && success
        end
      end

      if success
        render_attachment_warning_if_needed(@test_case)
        flash[:notice] = l(:notice_successful_update)
        redirect_to :controller => :impasse_test_case, :action => :index, :anchor => "testcase-#{@node.id}"
      end

    rescue ActiveRecord::ActiveRecordError=> e
      errors = []
      errors.concat(@node.errors.full_messages).concat(@test_case.errors.full_messages)
      if @test_steps
        @test_steps.each {|test_step|
          test_step.errors.full_messages.each {|msg|
            errors << "##{test_step.step_number} #{msg}"
          }
        }
      end
      flash.now[:error] = errors.join("<br>")
      render :edit
    end
  end

  def destroy
    params[:node][:id].each do |id|
      node = Impasse::Node.find(id)
      planed_node = []
      delete_test_suite = []
      ActiveRecord::Base.transaction do
        node.self_and_descendants.each do |child|
          if child.planned?
            Impasse::TestCase.update_all({:active => false}, ["id=?", child.id])
            planed_node << child
          else
            if child.node_type_id == 2
              delete_test_suite << child
            end
            if child.node_type_id == 3
              Impasse::TestCase.delete(child.id)
              child.destroy
            end
          end
        end
        delete_test_suite.each do |t_suite|
          if planed_node.all? {|ic| not ic.self_and_ancestors.include? t_suite }
            Impasse::TestSuite.delete(t_suite.id)
            t_suite.destroy
          end
        end
      end
    end
    render :json => {:status => true}
  end

  def keywords
    keywords = Impasse::Keyword.find_all_by_project_id(@project).map{|r| r.keyword}
    render :json => keywords
  end

  def copy
    nodes = []
    params[:nodes].each do |i,node_params|
      ActiveRecord::Base.transaction do 
        original_node = Impasse::Node.find(node_params[:original_id])
        original_node[:node_order] = node_params[:node_order]
        node, test_case = copy_node(original_node, node_params[:parent_id])
        test_case.attributes.merge({:name => node.name})
        nodes << node
      end
    end
    render :json => nodes
  end

  def move
    nodes = []
    params[:nodes].each do |i,node_params|
      ActiveRecord::Base.transaction do 
        node = Impasse::Node.find(node_params[:id])
        node.attributes = node_params
        save_node(node)
        nodes << node
      end
    end
    Impasse::Node.update_order_lft(nodes.first)
    render :json => nodes
  end

  private
  def get_settings
    @setting = Impasse::Setting.find_by_project_id(@project) || Impasse::Setting.create(:project_id => @project.id)
  end

  def save_node(node)
    success = node.save!
    success = node.update_siblings_order! && success
    return success
  end

  def get_root_name(test_plan_id)
    if test_plan_id.nil?
      @project.name
    else
      test_plan = Impasse::TestPlan.find(test_plan_id)
      test_plan.name
    end
  end

  def find_project
    begin
      @project = Project.find(params[:project_id])
      @project_node = Impasse::Node.find(:first, :conditions=>["name=? and node_type_id=?", @project.identifier, 1])
      if @project_node.nil?
        @project_node = Impasse::Node.new(:name=>@project.identifier, :node_type_id=>1, :node_order=>1)
        @project_node.save
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

  def copy_node(original_node, parent_id, level=0)
    node = original_node.dup

    if node.is_test_case?
      original_case = Impasse::TestCase.find(original_node.id, :include => :test_steps)
      test_case = original_case.dup
      original_case.test_steps.each{|ts| test_case.test_steps << ts.dup }
    else
      original_case = Impasse::TestSuite.find(original_node.id)
      test_case = original_case.dup
    end

    node.parent_id = parent_id
    node.name = "#{l(:button_copy)}_#{node.name}"
    node.save!
    node.update_siblings_order!
    Impasse::Node.update_order_lft(node)
    test_case.id = node.id
    test_case.save!

    if original_node.is_test_suite?
      original_node.children.each do |child|
        copy_node(child, node.id, level + 1)
      end
    end
    [node, test_case]
  end

  def convert(nodes, prefix='node')
    node_map = {}
    jstree_nodes = []
    node_test_cases = nodes.reject{|x| x if not x.is_test_case?}
    for node in nodes
      jstree_node = {
        'attr' => {'id' => "#{prefix}_#{node.id}" , 'rel' => REL[node.node_type_id] },
        'data' => {},
        'children'=>[]}

      if node.is_test_project?
        jstree_node['data']['title'] = node.name
      end

      if node.is_test_suite?
        count_children = node_test_cases.collect{|x| x if node.lft < x.lft and node.rgt > x.rgt }.compact.count
        jstree_node['data']['title'] = "#{node.name} (#{count_children})"
        jstree_node['state'] = 'closed'
      end

      if node.is_test_case?
        jstree_node['data']['title'] = "#{node.id} - #{node.name}"
        if not node.active?
          jstree_node['attr']['data-inactive'] = true
        end
      end

      node_map[node.id] = jstree_node
      if node_map.include? node.parent_id
        # non-root node
        node_map[node.parent_id]['children'] << jstree_node
        node_map[node.parent_id]['state'] = 'open'
      else
        #root node
        jstree_nodes << jstree_node
      end
    end
    jstree_nodes
  end

end
