# encoding: utf-8
class HomepageController < ApplicationController

  before_filter :save_current_path, :except => :sign_in

  APP_DEFAULT_VIEW_TYPE = "grid"
  VIEW_TYPES = ["grid", "list", "map"]

  def index
    ## Support old /?map=true URL START
    ## This can be removed after March 2014
    if !params[:view] && params[:map] == "true" then
      redirect_params = params.except(:map).merge({view: "map"})
      redirect_to url_for(redirect_params), status: :moved_permanently
    end
    ## Support old /?map=true URL END

    @homepage = true

    @view_type = HomepageController.selected_view_type(params[:view], @current_community.default_browse_view, APP_DEFAULT_VIEW_TYPE, VIEW_TYPES)

    @categories = @current_community.categories
    @main_categories = @current_community.main_categories
    @listing_shapes = @current_community.listing_shapes

    # This assumes that we don't never ever have communities with only 1 main share type and
    # only 1 sub share type, as that would make the listing type menu visible and it would look bit silly
    listing_shape_menu_enabled = @listing_shapes.size > 1
    @show_categories = @current_community.categories.size > 1
    filters_enabled = @current_community.custom_fields.size > 0 || @current_community.show_price_filter
    @show_custom_fields = @current_community.custom_fields.select { |field| field.can_filter? }.present?
    @category_menu_enabled = @show_categories || @show_custom_fields || filters_enabled

    @app_store_badge_filename = "/assets/Available_on_the_App_Store_Badge_en_135x40.svg"
    if File.exists?("app/assets/images/Available_on_the_App_Store_Badge_#{I18n.locale}_135x40.svg")
       @app_store_badge_filename = "/assets/Available_on_the_App_Store_Badge_#{I18n.locale}_135x40.svg"
    end

    listings_per_page = APP_CONFIG.grid_listings_limit

    @listings = if @view_type == "map"
      find_listings(params, APP_CONFIG.map_listings_limit)
    else
      find_listings(params, listings_per_page)
    end

    if request.xhr? # checks if AJAX request
      if @view_type == "grid" then
        render :partial => "grid_item", :collection => @listings, :as => :listing
      else
        render :partial => "list_item", :collection => @listings, :as => :listing
      end
    end

    render locals: {
             listing_shape_menu_enabled: listing_shape_menu_enabled,
             selected_listing_shape: @selected_listing_shape
           }
  end

  def self.selected_view_type(view_param, community_default, app_default, all_types)
    if view_param.present? and all_types.include?(view_param)
      view_param
    elsif community_default.present? and all_types.include?(community_default)
      community_default
    else
      app_default
    end
  end

  private

  def find_listings(params, listings_per_page)
    filter_params = {}

    Maybe(@current_community.categories.find_by_url_or_id(params[:category])).each do |category|
      filter_params[:category] = category.id
      @selected_category = category
    end

    Maybe(@current_community.listing_shapes.find_by_param(params[:listing_shape])).each do |listing_shape|
      filter_params[:listing_shape] = listing_shape.id
      @selected_listing_shape = listing_shape
    end

    @listing_count = @current_community.listings.currently_open.count
    unless @current_user
      @private_listing_count = Listing.currently_open.private_to_community(@current_community).count
    end

    filter_params[:search] = params[:q] if params[:q]
    filter_params[:include] = [:listing_images, :author, :category, :listing_shape]
    filter_params[:custom_dropdown_field_options] = HomepageController.dropdown_field_options_for_search(params)
    filter_params[:custom_checkbox_field_options] = HomepageController.checkbox_field_options_for_search(params)

    filter_params[:price_cents] = filter_range(params[:price_min], params[:price_max])

    p = HomepageController.numeric_filter_params(params)
    p = HomepageController.parse_numeric_filter_params(p)
    p = HomepageController.group_to_ranges(p)
    numeric_search_params = HomepageController.filter_unnecessary(p, @current_community.custom_numeric_fields)

    numeric_search_needed = !numeric_search_params.empty?

    filter_params[:listing_id] = if numeric_search_needed
      NumericFieldValue.search_many(numeric_search_params).collect(&:listing_id)
    end

    if numeric_search_needed && filter_params[:listing_id].empty?
      Listing.none.paginate(:per_page => listings_per_page, :page => params[:page])
    else
      Listing.find_with(filter_params, @current_user, @current_community, listings_per_page, params[:page])
    end
  end

  def filter_range(price_min, price_max)
    if (price_min && price_max)
      min = MoneyUtil.parse_str_to_money(price_min, @current_community.default_currency).cents
      max = MoneyUtil.parse_str_to_money(price_max, @current_community.default_currency).cents

      if ((@current_community.price_filter_min..@current_community.price_filter_max) != (min..max))
        (min..max)
      else
        nil
      end
    end
  end

  # Return all params starting with `numeric_filter_`
  def self.numeric_filter_params(all_params)
    all_params.select { |key, value| key.start_with?("nf_") }
  end

  def self.parse_numeric_filter_params(numeric_params)
    numeric_params.inject([]) do |memo, numeric_param|
      key, value = numeric_param
      _, boundary, id = key.split("_")

      hash = {id: id.to_i}
      hash[boundary.to_sym] = value
      memo << hash
    end
  end

  def self.group_to_ranges(parsed_params)
    parsed_params
      .group_by { |param| param[:id] }
      .map do |key, values|
        boundaries = values.inject(:merge)

        {
          custom_field_id: key,
          numeric_value: (boundaries[:min].to_f..boundaries[:max].to_f)
        }
      end
  end

  # Filter search params if their values equal min/max
  def self.filter_unnecessary(search_params, numeric_fields)
    search_params.reject do |search_param|
      numeric_field = numeric_fields.find(search_param[:custom_field_id])
      search_param == { custom_field_id: numeric_field.id, numeric_value: (numeric_field.min..numeric_field.max) }
    end
  end

  def self.options_from_params(params, regexp)
    option_ids = HashUtils.select_by_key_regexp(params, regexp).values

    array_for_search = CustomFieldOption.find(option_ids)
      .group_by { |option| option.custom_field_id }
      .map { |key, selected_options| selected_options.collect(&:id) }
  end

  def self.dropdown_field_options_for_search(params)
    options_from_params(params, /^filter_option/)
  end

  def self.checkbox_field_options_for_search(params)
    options_from_params(params, /^checkbox_filter_option/).flatten
  end
end
