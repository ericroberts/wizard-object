class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name, null: false, default: ''
      t.string :price, null: false, default: ''
      t.string :category, null: false, default: ''

      t.timestamps
    end
  end
end
