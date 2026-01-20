# frozen_string_literal: true

# Sitemap configuration for search engine indexing
# Regenerated automatically on deploy via Kamal post-deploy hook
# Manual refresh: bin/rails sitemap:refresh
#
# Discovery: Search engines find the sitemap via robots.txt
# Sitemaps are uploaded to DigitalOcean Spaces (S3-compatible)

SitemapGenerator::Sitemap.default_host = "https://app.nybenchmark.org"

# Upload to DigitalOcean Spaces (S3-compatible storage)
SitemapGenerator::Sitemap.adapter = SitemapGenerator::AwsSdkAdapter.new(
  ENV.fetch("DO_SPACES_BUCKET", "nybenchmark-production"),
  aws_access_key_id: ENV.fetch("DO_SPACES_KEY", nil),
  aws_secret_access_key: ENV.fetch("DO_SPACES_SECRET", nil),
  aws_region: "us-east-1",
  endpoint: "https://nyc3.digitaloceanspaces.com"
)

# Store sitemaps in a 'sitemaps' folder within the bucket
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"

# Public URL where sitemaps will be accessible
SitemapGenerator::Sitemap.sitemaps_host = "https://nybenchmark-production.nyc3.digitaloceanspaces.com/"

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
