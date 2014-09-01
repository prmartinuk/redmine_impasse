module Impasse
  class Execution < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_executions"
    self.include_root_in_json = false

    belongs_to :test_plan
    belongs_to :test_case
    has_many :issues, :through => :execution_bugs
    belongs_to :tester, :class_name => "User", :foreign_key => "tester_id"
    has_many :execution_bugs
    has_many :execution_histories


    acts_as_customizable

    def self.find_planned(node_id, test_plan_id)
      parent_node = Node.find(node_id)
      test_plan_cases = TestPlanCase.where(:test_plan_id => test_plan_id).map(&:test_case_id)
      nodes = parent_node.find_with_children_test_case.where("id IN (?)", test_plan_cases)

      executions = Execution.scoped
      executions = executions.where("test_plan_id = ? AND test_case_id IN (?)", test_plan_id.to_i, nodes.map(&:id))

      nodes_group_by_parent = nodes.group_by(&:parent_id)
      nodes_group_by_parent.each do |parent_id, nodes_by_parent|
        min_lft = nodes_by_parent.map(&:lft).min  
        max_rgt = nodes_by_parent.map(&:rgt).max
        nodes += Node.where("(lft < ? AND rgt > ?) AND (lft >= ? AND rgt <= ?)", min_lft, max_rgt, parent_node.lft, parent_node.rgt)
      end
      nodes.uniq
      ret = {}
      nodes.each do |node|
        node_executions = executions.collect {|x| x if x.test_case_id == node.id}.compact[0]
        ret[node] = node_executions
      end
      ret
    end

    def self.find_executed(node_id, test_plan_id, filters={})
      parent_node = Node.find(node_id)
      test_plan_cases = TestPlanCase.where(:test_plan_id => test_plan_id).map(&:test_case_id)
      child_nodes = parent_node.find_with_children_test_case.where("id IN (?)", test_plan_cases)
      
      executions = Execution.scoped
      executions = executions.where("test_plan_id = ? AND test_case_id IN (?)", test_plan_id.to_i, child_nodes)

      if filters[:myself]
        executions = executions.where(:tester_id => User.current.id)
      end

      if filters[:execution_status]
        if filters[:execution_status].is_a? Array
          execution_status = filters[:execution_status]
        else
          execution_status = [filters[:execution_status]]
        end
        condition = "status IN (" + execution_status.collect{|val| "'#{val}'" }.join(',') + ")"
        if execution_status.include? "0"
          condition += " OR status IS NULL"
        end
        executions = executions.where(condition)
      end

      if filters[:expected_date]
        conditions_date = filters[:expected_date_op] || '='
        executions = executions.where("expected_date #{conditions_date} #{filters[:expected_date]}")
      end

      test_cases = executions.map(&:test_case)
      nodes = test_cases.map(&:node)
      nodes_group_by_parent = nodes.group_by(&:parent_id)
      nodes_group_by_parent.each do |parent_id, nodes_by_parent|
        min_lft = nodes_by_parent.map(&:lft).min  
        max_rgt = nodes_by_parent.map(&:rgt).max
        nodes += Impasse::Node.where("(lft < ? AND rgt > ?) AND (lft >= ? AND rgt <= ?)", min_lft, max_rgt, parent_node.lft, parent_node.rgt)
      end
      nodes.uniq

      ret = {}
      nodes.each do |node|
        execution = executions.collect {|x| x if x.test_case_id == node.id}.compact[0]
        ret[node] = execution
      end
      ret
    end
  end
end
