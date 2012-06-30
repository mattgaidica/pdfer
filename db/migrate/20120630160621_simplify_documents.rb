class SimplifyDocuments < ActiveRecord::Migration
  def up
    remove_column :documents, :original
    remove_column :documents, :pdf
    remove_column :documents, :text
  end

  def down
    add_column :documents, :original, :string
    add_column :documents, :pdf, :string
    add_column :documents, :text, :string
  end
end
