class AddStorage < ActiveRecord::Migration
  def up
    create_table :storage do |t|
      t.string :local
      t.string :remote
      t.timestamps
    end
  end

  def down
    drop_table :storage
  end
end
