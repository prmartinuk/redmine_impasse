require 'erb'

class ImpasseExecutionsController < ApplicationController
  unloadable

  REL = {
    1 => "test_project",
    2 => "test_suite",
    3 => "test_case"
  }

  helper :custom_fields
  include CustomFieldsHelper

  menu_item :impasse
  before_filter :find_project_by_project_id

  include ActionView::Helpers::AssetTagHelper

  def index
    params[:tab] = 'execution'
    @test_plan = Impasse::TestPlan.find(params[:id])
  end

  def put
    @node = Impasse::Node.find(params[:test_plan_case][:test_case_id])
    test_case_ids = if @node.is_test_case? then [ @node.id ] else @node.find_with_children_test_case.map(&:id) end
    if params[:execution] and params[:execution][:expected_date]
      params[:execution][:expected_date] = Time.at(params[:execution][:expected_date].to_i)
    end
    status = 'success'
    errors = []
    for test_case_id in test_case_ids
      test_plan_case = Impasse::TestPlanCase.find_by_test_plan_id_and_test_case_id(params[:test_plan_case][:test_plan_id], test_case_id)
      next if test_plan_case.nil?
      execution = Impasse::Execution.find_or_initialize_by_test_plan_id_and_test_case_id(params[:test_plan_case][:test_plan_id], test_case_id)
      execution.attributes = params[:execution]
      if params[:record]
        execution.execution_ts = Time.now.to_datetime
        execution.executor_id = User.current.id
      end
      begin
        ActiveRecord::Base.transaction do
          execution.save!
          if params[:record]
            @execution_history = Impasse::ExecutionHistory.new(:execution_id => execution.id,
                                                               :tester_id => execution.tester_id,
                                                               :build_id => execution.build_id,
                                                               :expected_date => execution.expected_date,
                                                               :status => execution.status,
                                                               :execution_ts => execution.execution_ts,
                                                               :executor_id => execution.executor_id,
                                                              :notes => execution.notes)
            @execution_history.save!
          end
        end
      rescue
        errors.concat(execution.errors.full_messages)
      end
    end
    
    if errors.empty?
      render :json => { :status => 'success', :message => l(:notice_successful_update) }
    else
      render :json => { :status => 'error', :message => l(:error_failed_to_update), :errors => errors }
    end
  end

  def destroy
    node = Impasse::Node.find(params[:test_plan_case][:test_case_id])
    test_case_ids = (node.is_test_case?) ? [ node.id ] : node.find_with_children_test_case.collect{|tc| tc.id}
    status = true
    for test_case_id in test_case_ids
      test_plan_case = Impasse::TestPlanCase.find_by_test_plan_id_and_test_case_id(params[:test_plan_case][:test_plan_id], test_case_id)
      next if test_plan_case.nil?
      execution = Impasse::Execution.find_by_test_plan_id_and_test_case_id(params[:test_plan_case][:test_plan_id], test_case_id)
      next if execution.nil?
      execution.tester_id = execution.expected_date = nil
      satus &= execution.save
    end
    render :json => { :status => status }
  end

  def get_planned
    if params[:id].to_i == -1
      root = Impasse::Node.find_by_name_and_node_type_id(@project.identifier, 1)
    else
      root = Impasse::Node.find(params[:id])
    end
    nodes = Impasse::Execution.find_planned(root.id, params[:test_plan_id])
    jstree_nodes = convert(nodes, params[:prefix])
    render :json => jstree_nodes
  end

  def get_executed
    if params[:id].to_i == -1
      root = Impasse::Node.find_by_name_and_node_type_id(@project.identifier, 1)
    else
      root = Impasse::Node.find(params[:id])
    end
    nodes = Impasse::Execution.find_executed(root.id, params[:test_plan_id], params[:filters] || {})
    jstree_nodes = convert(nodes, params[:prefix])
    render :json => jstree_nodes
  end

  def edit
    @execution = Impasse::Execution.find_by_test_plan_id_and_test_case_id(params[:test_plan_case][:test_plan_id], params[:test_plan_case][:test_case_id])
    if @execution.nil?
      @execution = Impasse::Execution.new
      @execution.attributes = params[:test_plan_case]
    end
    if params.include? :execution
      @execution.attributes = params[:execution]
    end
    @execution_histories = @execution.execution_histories.order(:execution_ts)
    if request.post? and @execution.save
      render :json => {'status'=>true}
    else
      render :layout => false
    end
  end

  private
  def convert(nodes, prefix='node')
    node_map = {}
    jstree_nodes = []
    node_test_cases = nodes.keys.reject{|x| x if x.node_type_id != 3}
    for node in nodes.keys.sort_by(&:lft)
      execution = nodes[node]
      jstree_node = {
        'attr' => {'id' => "#{prefix}_#{node.id}" , 'rel' => REL[node.node_type_id]},
        'data' => {},
        'children'=>[]}
      if node.node_type_id == 3  
        jstree_node['data']['title'] = "#{node.id} - #{node.name}"
      else
        count_children = node_test_cases.collect{|x| x if node.lft < x.lft and node.rgt > x.rgt }.compact.count
        jstree_node['data']['title'] = "#{node.name} (#{count_children})"
      end
      if node.node_type_id == 2
        jstree_node['state'] = 'closed'
      end
      assign_text = []
      unless execution.nil?
        if execution.tester.present?
          assign_text << execution.tester
        end
        if execution.expected_date
          assign_text << format_date(execution.expected_date.to_date)
        end
      end
      if assign_text.size > 0
        jstree_node['data']['title'] << " (#{assign_text.join(' ')})"
      end

      jstree_node['data']['icon'] = status_icon(execution.status) if node.node_type_id == 3 and execution

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

  def status_icon(status)
    icon_dir = Redmine::Utils::relative_url_root + "/plugin_assets/redmine_impasse/stylesheets/images"
    [
     "#{icon_dir}/document-attribute-t.png",
     "#{icon_dir}/tick.png",
     "#{icon_dir}/cross.png",
     "#{icon_dir}/wall-brick.png",
    ][status.to_i]
  end
end
