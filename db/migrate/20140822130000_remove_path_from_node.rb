class RemovePathFromNode < ActiveRecord::Migration
  def self.up
    remove_column :impasse_nodes, :path
  end

  def self.down
    add_column :impasse_nodes, :path, :string, :null => false, :default => '.'
    add_index :impasse_nodes, :path, :name => 'IDX_IMPASSE_NODES_02'
  end
end
