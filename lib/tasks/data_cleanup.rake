# frozen_string_literal: true

namespace :data do
  desc "Remove manually-entered documents and observations (keeps OSC and Census data)"
  task cleanup_manual: :environment do
    manual_doc_types = %w[acfr demographics public_safety census school_financials school_budget]

    puts "=" * 60
    puts "WARNING: This will delete all manually-entered documents"
    puts "and their observations."
    puts ""
    puts "Doc types to remove: #{manual_doc_types.join(', ')}"
    puts "OSC and Census data will be preserved."
    puts "=" * 60
    puts ""
    puts "Current counts:"
    puts "  Entities:     #{Entity.count}"
    puts "  Documents:    #{Document.count}"
    puts "  Metrics:      #{Metric.count}"
    puts "  Observations: #{Observation.count}"
    puts "  Users:        #{User.count}"
    puts ""

    docs_to_delete = Document.where(doc_type: manual_doc_types)
    puts "Documents to delete: #{docs_to_delete.count}"

    docs_to_delete.includes(:entity).group_by(&:entity).each do |entity, docs|
      docs.each do |doc|
        obs_count = doc.observations.count
        puts "  #{entity.name} — #{doc.doc_type} FY#{doc.fiscal_year} (#{obs_count} observations)"
      end
    end

    obs_to_delete = Observation.where(document: docs_to_delete)
    puts ""
    puts "Total observations to delete: #{obs_to_delete.count}"
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
      obs_count = obs_to_delete.count
      obs_to_delete.delete_all
      puts "  Deleted #{obs_count} observations"

      puts "Deleting documents..."
      doc_count = docs_to_delete.count
      docs_to_delete.each { |doc| doc.file.purge if doc.file.attached? }
      docs_to_delete.delete_all
      puts "  Deleted #{doc_count} documents"

      puts "Checking for orphaned metrics..."
      orphaned = Metric.where(data_source: [ :manual, :rating_agency ])
                       .where.not(id: Observation.select(:metric_id).distinct)
      orphaned_count = orphaned.count
      if orphaned_count > 0
        orphaned.each { |m| puts "  Removing: #{m.label} (#{m.data_source})" }
        orphaned.delete_all
      end
      puts "  Deleted #{orphaned_count} orphaned metrics"

      puts ""
      puts "=" * 60
      puts "Cleanup complete!"
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
end
