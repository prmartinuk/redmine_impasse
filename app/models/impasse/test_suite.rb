module Impasse
  class TestSuite < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_test_suites"
    self.include_root_in_json = false

    belongs_to :node, :foreign_key => :id

    acts_as_customizable

    def name
      self.node.name
    end

  end
end
