class CreateDocuments < ActiveRecord::Migration
  def up
    create_table :documents do |t|
      t.string :token
      t.string :original
      t.string :pdf
      t.string :text
      t.boolean :complete
      t.timestamps
    end

    create_table :images do |t|
      t.integer :document_id
      t.string :size
      t.string :image
      t.timestamps
    end
  end

  def down
    drop_table :documents
    drop_table :images
  end
end
