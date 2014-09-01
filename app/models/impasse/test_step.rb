module Impasse
  class TestStep < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_test_steps"

    belongs_to :test_case
    
    validates_presence_of :actions

  end
end
