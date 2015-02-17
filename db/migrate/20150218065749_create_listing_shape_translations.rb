class CreateListingShapeTranslations < ActiveRecord::Migration
  def up
    create_table :listing_shape_translations do |t|
      t.integer :listing_shape_id, null: false
      t.string :locale, null: false
      t.string :name
      t.string :action_button_label

      t.timestamps null: false
    end

    add_index :listing_shape_translations, :listing_shape_id
    add_index :listing_shape_translations, :locale
  end

  def down
    drop_table :listing_shape_translations
  end
end
