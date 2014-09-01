module Impasse
  class TestCase < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_test_cases"
    self.include_root_in_json = false
    
    has_many :test_steps, :dependent=>:destroy, :order => "step_number"
    belongs_to :node, :foreign_key=>"id"
    has_many :requirement_cases
    has_many :requirement_issues, :through => :requirement_cases
    has_many :test_plan_cases
    has_many :test_plans, :through => :test_plan_cases
    has_many :executions

    acts_as_customizable
    acts_as_attachable

    def project
      root = self.node.root
      Project.find_by_identifier(root.name)
    end

    def name
      self.node.name
    end

    def attachments_visible?(*args)
      #Fix in the future
      true
    end

    def attachments_deletable?(*args)
      #Fix in the future
      true
    end

  end
end
