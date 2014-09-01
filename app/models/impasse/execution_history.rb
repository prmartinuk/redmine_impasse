module Impasse
  class ExecutionHistory < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_execution_histories"
    self.include_root_in_json = false

    belongs_to :execution
    belongs_to :executor, :class_name => "User"
    acts_as_customizable
  end
end
