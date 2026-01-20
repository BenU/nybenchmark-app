# frozen_string_literal: true

# Sitemap configuration for search engine indexing
# Regenerated automatically on deploy via Kamal post-deploy hook
# Manual refresh: bin/rails sitemap:refresh
#
# Discovery: Search engines find the sitemap via robots.txt
# Google deprecated ping endpoints in June 2023

SitemapGenerator::Sitemap.default_host = "https://app.nybenchmark.org"

# Store sitemaps in public/ for direct serving by Rails
SitemapGenerator::Sitemap.public_path = "public/"
SitemapGenerator::Sitemap.sitemaps_path = ""

SitemapGenerator::Sitemap.create do
  # Root page is added automatically

  # Entities - primary public pages (government bodies)
  Entity.find_each do |entity|
    add entity_path(entity), lastmod: entity.updated_at, changefreq: "weekly", priority: 0.8
  end

  # Documents - source financial/statistical documents
  Document.find_each do |document|
    add document_path(document), lastmod: document.updated_at, changefreq: "monthly", priority: 0.6
  end

  # Metrics - standardized datapoint definitions
  Metric.find_each do |metric|
    add metric_path(metric), lastmod: metric.updated_at, changefreq: "monthly", priority: 0.5
  end

  # Observations - individual extracted facts
  Observation.find_each do |observation|
    add observation_path(observation), lastmod: observation.updated_at, changefreq: "monthly", priority: 0.4
  end
end
