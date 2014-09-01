class AddQueryIdToTestPlans < ActiveRecord::Migration
  def self.up
    add_column :impasse_test_plans, :query_id, :integer
  end

  def self.down
    remove_column :impasse_test_plans, :query_id
  end
end
