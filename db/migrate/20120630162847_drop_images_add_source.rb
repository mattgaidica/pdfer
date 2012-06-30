class DropImagesAddSource < ActiveRecord::Migration
  def up
    add_column :documents, :source, :string
    drop_table :images
  end

  def down
    remove_column :documents, :source
    create_table :images
  end
end
