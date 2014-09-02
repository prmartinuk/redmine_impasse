class AddIndexOnNodeNestedSet < ActiveRecord::Migration
  def self.up
    remove_index :impasse_nodes, :name => 'IDX_IMPASSE_NODES_LFT'
    remove_index :impasse_nodes, :name => 'IDX_IMPASSE_NODES_RGT'
    remove_index :impasse_nodes, :name => 'IDX_IMPASSE_NODES_01'
    add_index :impasse_nodes, [:parent_id, :lft, :rgt]
  end

  def self.down
    remove_index :impasse_nodes, [:parent_id, :lft, :rgt]
    add_index :impasse_nodes, :lft, :name => 'IDX_IMPASSE_NODES_LFT'
    add_index :impasse_nodes, :rgt, :name => 'IDX_IMPASSE_NODES_RGT'
    add_index :impasse_nodes, :parent_id, :name => 'IDX_IMPASSE_NODES_01'
  end
end
