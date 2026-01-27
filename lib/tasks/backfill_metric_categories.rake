# frozen_string_literal: true

require "csv"

namespace :osc do
  desc "Backfill level_1_category and level_2_category for existing metrics from OSC CSV files"
  task backfill_categories: :environment do
    osc_data_dir = Rails.root.join("db/seeds/osc_data/city_all_years")

    puts "=" * 60
    puts "Backfilling metric categories from OSC CSV files"
    puts "=" * 60
    puts ""

    # Build a mapping of account_code -> categories from CSV files
    # We only need one row per account code since categories are consistent
    category_map = {}

    csv_files = Dir.glob(osc_data_dir.join("*_City.csv"))
    puts "Reading #{csv_files.count} CSV files..."

    csv_files.each do |file|
      CSV.foreach(file, headers: true) do |row|
        account_code = row["ACCOUNT_CODE"]
        next if account_code.blank?
        next if category_map.key?(account_code) # Already have this one

        cat1 = row["LEVEL_1_CATEGORY"]
        cat2 = row["LEVEL_2_CATEGORY"]

        # Only store if we have at least one category
        next if cat1.blank? && cat2.blank?

        category_map[account_code] = {
          level_1_category: cat1.presence,
          level_2_category: cat2.presence
        }
      end
    end

    puts "Found categories for #{category_map.count} account codes"
    puts ""

    # Update metrics
    updated = 0
    skipped = 0
    not_found = 0

    Metric.osc_data_source.find_each do |metric|
      categories = category_map[metric.account_code]

      if categories.nil?
        not_found += 1
        next
      end

      if metric.level_1_category == categories[:level_1_category] &&
         metric.level_2_category == categories[:level_2_category]
        skipped += 1
        next
      end

      metric.update!(
        level_1_category: categories[:level_1_category],
        level_2_category: categories[:level_2_category]
      )
      updated += 1
    end

    puts "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Metrics updated:  #{updated}"
    puts "Already correct:  #{skipped}"
    puts "No category data: #{not_found}"
    puts ""

    # Show sample of updated metrics
    puts "Sample categories:"
    Metric.where.not(level_1_category: nil).limit(10).each do |m|
      puts "  #{m.account_code.to_s.ljust(8)} | #{m.level_1_category.to_s.ljust(20)} | #{m.level_2_category}"
    end
  end
end
