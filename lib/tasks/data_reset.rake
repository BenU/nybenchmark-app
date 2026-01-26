# frozen_string_literal: true

namespace :data do
  desc "Reset observations and metrics only (DESTRUCTIVE - keeps entities, documents, and users)"
  task reset_for_osc: :environment do
    puts "=" * 60
    puts "WARNING: This will delete ALL observations and metrics!"
    puts "Entities, documents, and users will be preserved."
    puts "=" * 60
    puts ""
    puts "Current counts:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
    puts "  Users:        #{User.count}"
    puts ""
    puts "Press Ctrl+C within 5 seconds to cancel..."

    5.times do |i|
      print "#{5 - i}... "
      sleep 1
    end
    puts ""

    ActiveRecord::Base.transaction do
      puts ""
      puts "Deleting observations..."
      obs_count = Observation.count
      Observation.delete_all
      puts "  Deleted #{obs_count} observations"

      puts "Deleting metrics..."
      metric_count = Metric.count
      Metric.delete_all
      puts "  Deleted #{metric_count} metrics"

      puts ""
      puts "=" * 60
      puts "Reset complete!"
      puts "=" * 60
      puts ""
      puts "Remaining counts:"
      puts "  Entities:     #{Entity.count}"
      puts "  Documents:    #{Document.count}"
      puts "  Metrics:      #{Metric.count}"
      puts "  Observations: #{Observation.count}"
      puts "  Users:        #{User.count}"
    end
  end

  desc "Show current data counts (non-destructive)"
  task counts: :environment do
    puts "Current data counts:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
    puts "  Users:        #{User.count}"
  end
end
