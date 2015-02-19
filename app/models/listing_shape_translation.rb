# == Schema Information
#
# Table name: listing_shape_translations
#
#  id                  :integer          not null, primary key
#  listing_shape_id    :integer          not null
#  locale              :string(255)      not null
#  name                :string(255)
#  action_button_label :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_listing_shape_translations_on_listing_shape_id  (listing_shape_id)
#  index_listing_shape_translations_on_locale            (locale)
#

class ListingShapeTranslation < ActiveRecord::Base
  attr_accessible :locale, :name, :action_button_label

  belongs_to :listing_shape
end
