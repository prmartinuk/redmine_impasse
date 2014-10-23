class AddIndexNodeOrderAndParentId < ActiveRecord::Migration
  def self.up
    add_index :impasse_nodes, [:parent_id, :node_order]
    add_index :impasse_nodes, :lft
  end

  def self.down
    remove_index :impasse_nodes, [:parent_id, :node_order]
    remove_index :impasse_nodes, :lft
  end
end
