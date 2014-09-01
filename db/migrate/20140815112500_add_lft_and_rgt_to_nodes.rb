class AddLftAndRgtToNodes < ActiveRecord::Migration
  def self.up
    add_column :impasse_nodes, :lft, :integer, :default => 0
    add_column :impasse_nodes, :rgt, :integer, :default => 0
    add_index :impasse_nodes, :lft, :name => 'IDX_IMPASSE_NODES_LFT'
    add_index :impasse_nodes, :rgt, :name => 'IDX_IMPASSE_NODES_RGT'
    Impasse::Node.rebuild!
  end

  def self.down
    remove_column :impasse_nodes, :lft
    remove_column :impasse_nodes, :rgt
  end
end
