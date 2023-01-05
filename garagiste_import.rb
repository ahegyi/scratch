# frozen_string_literal: true

# Use at your own risk.

# get JSON from https://garagiste.com/shipments and look at the react state for "shipments" key,
#   write it to a file and use it as the argument when running this script.

require 'csv'
require 'json'

GARAGISTE_STORE = 'Garagiste'
USD_CURRENCY = 'USD'

# The export CSV will be imported into cellartracker.
# BottleState, Location, Bin, PrivateNote, and scores should be added before importing.
# TODO: Use CellarTracker import template for CSV headers.

csv_headers = %w[shipment_id
                 state
                 BottleState
                 vintage
                 good_name
                 mystery_best_guess_name
                 producer_name
                 region
                 country
                 color
                 Quantity
                 BottleSize
                 Location
                 Bin
                 BeginConsume
                 EndConsume
                 Store
                 PurchaseDate
                 DeliveryDate
                 BottleCost
                 BottleCostCurrency
                 PrivateNote
                 wa_score
                 wa_text
                 wa_begin
                 wa_end
                 ws_score
                 ws_text
                 ws_begin
                 ws_end
                 we_score
                 we_text
                 we_begin
                 we_end]

# code here to parse JSON from garagiste json and write new CSV
shipments = JSON.parse(File.read(ARGV[0]))

rows_to_write = []

shipments.each do |shipment|
  shipment_goods = shipment['goods']
  shipment_items = shipment['items_by_count']

  shipment_items.each do |line_item|
    new_row = {}

    good = shipment_goods.find { |g| g['id'] == line_item['good_id'].to_s }
    customer_inventory = shipment['customer_inventories'].find { |cust_inventory| cust_inventory['good']['id'] == line_item['good_id'].to_s }
    # The offering that the good was ordered from.
    ordered_offering_id = customer_inventory['offering_id'].to_s

    new_row['shipment_id'] = shipment['id']
    # e.g. "shipped"
    new_row['state'] = customer_inventory['state']
    new_row['vintage'] = good['vintage']
    new_row['good_name'] = good['name']
    if good['name'].downcase.include?('mystery') && good['name'].include?(' - ')
      new_row['mystery_best_guess_name'] = good['name'].split(' - ').last
    end
    new_row['producer_name'] = good['producer_name']
    new_row['region'] = good['region']
    new_row['country'] = good['country']
    new_row['color'] = good['color']
    new_row['Quantity'] = line_item['count']
    new_row['BottleSize'] = good['product_size']
    # don't deal with date parsing, we just care about year
    new_row['BeginConsume'] = good['optimal_consumption_start_at'] ? good['optimal_consumption_start_at'][0..3] : nil
    new_row['EndConsume'] = good['optimal_consumption_end_at'] ? good['optimal_consumption_end_at'][0..3] : nil
    new_row['Store'] = GARAGISTE_STORE
    # The customer inventory created date seems to be the same as the purchase date.
    new_row['PurchaseDate'] = Date.parse(customer_inventory['created_at'])
    new_row['DeliveryDate'] = Date.parse(shipment['ship_date'])
    # Sometimes a bottle (i.e. "good") can be offered more than once, which may not reflect the price paid.
    #   Unfortunately the price paid is not in the shipments.json; we'd need to cross reference "orders" or "requests".
    #   Workaround for now is to add these prices paid manually before importing to CellarTracker.
    if ordered_offering_id == good['last_offering']['id'].to_s
      new_row['BottleCost'] = good['last_offering']['price_in_cents'] / 100.0
    end
    new_row['BottleCostCurrency'] = USD_CURRENCY

    rows_to_write << new_row
  end
end

CSV.open('for_import.csv', 'wb') do |csv|
  csv << csv_headers
  rows_to_write.each do |hash|
    csv << hash.values_at(*csv_headers)
  end
end
