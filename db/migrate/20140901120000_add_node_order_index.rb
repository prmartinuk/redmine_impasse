class AddNodeOrderIndex < ActiveRecord::Migration
  def self.up
    add_index :impasse_nodes, :node_order, :name => 'IDX_IMPASSE_NODES_ORDER'
  end

  def self.down
    remove_index :impasse_nodes, :name => 'IDX_IMPASSE_NODES_ORDER'
  end
end
