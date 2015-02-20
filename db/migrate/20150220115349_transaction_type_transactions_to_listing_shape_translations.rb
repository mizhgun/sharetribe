class TransactionTypeTransactionsToListingShapeTranslations < ActiveRecord::Migration
  def up
    execute("
      INSERT INTO listing_shape_translations (listing_shape_id, locale, name, action_button_label, created_at, updated_at)
      (
        SELECT listing_shapes.id, ttt.locale, ttt.name, ttt.action_button_label, ttt.created_at, ttt.updated_at
        FROM listing_shapes, transaction_type_translations as ttt
        WHERE listing_shapes.transaction_type_id = ttt.transaction_type_id AND listing_shapes.id NOT IN
          (SELECT listing_shape_id FROM listing_shape_translations)
      )
")
  end

  def down
    execute("
      DELETE FROM listing_shape_translations
")
  end
end
