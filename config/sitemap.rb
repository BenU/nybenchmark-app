# frozen_string_literal: true

# Sitemap configuration for search engine indexing
# Regenerated automatically on every deploy via docker-entrypoint
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
  # Root/landing page added automatically

  # Entity pages - only include entities that have actual data (observations)
  # Avoids thin pages for entities added to the database but not yet imported
  Entity.where("EXISTS (SELECT 1 FROM observations WHERE observations.entity_id = entities.id)").find_each do |entity|
    add entity_path(entity), lastmod: entity.updated_at, changefreq: "weekly", priority: 0.8
  end

  # Content pages
  add methodology_path, changefreq: "monthly", priority: 0.6
  add non_filers_path, changefreq: "weekly", priority: 0.6

  # NOTE: When adding new public-facing pages (benchmarks, comparisons, etc.),
  # add them here. See CLAUDE.md "SEO & Sitemap" section.
  #
  # Documents, metrics, and observations are excluded intentionally — they are
  # admin/audit pages marked noindex (see ApplicationController#set_noindex).
end
