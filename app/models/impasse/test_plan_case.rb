module Impasse
  class TestPlanCase < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_test_plan_cases"
    self.include_root_in_json = false

    belongs_to :test_plan
    belongs_to :test_case

    def self.delete_cascade!(test_plan_id, test_case_id)
      node = Node.find(test_case_id)
      unless node.node_type_id == 3
        child_nodes = node.find_with_children_test_case
        child_nodes.each do |child_node|
          TestPlanCase.destroy_all(:test_case_id => child_node.id, :test_plan_id => test_plan_id)
        end
      else
        TestPlanCase.destroy_all(:test_case_id => node.id, :test_plan_id => test_plan_id)
      end
      # Удалить все связанные executions
    end
  end
end
