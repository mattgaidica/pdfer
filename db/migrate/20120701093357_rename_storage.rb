class RenameStorage < ActiveRecord::Migration
  def up
    rename_table :storage, :storages
  end

  def down
    rename_table :storages, :storage
  end
end
