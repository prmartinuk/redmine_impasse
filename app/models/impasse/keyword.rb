module Impasse
  class Keyword < ActiveRecord::Base
    unloadable
    self.table_name = "impasse_keywords"
    self.include_root_in_json = false

    belongs_to :project
  end
end
