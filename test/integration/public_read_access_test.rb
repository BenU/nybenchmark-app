# frozen_string_literal: true

require "test_helper"

class PublicReadAccessTest < ActionDispatch::IntegrationTest
  setup do
    # Your ApplicationController uses `allow_browser versions: :modern`.
    # Rails integration tests use a non-browser User-Agent by default, so we set a modern UA here.
    @headers = {
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
  end

  test "unauthenticated users can access read-only index/show pages" do
    # Entities
    get entities_path, headers: @headers
    assert_response :success

    entity = Entity.order(:id).first
    assert entity, "Expected at least one Entity record/fixture"
    get entity_path(entity.slug), headers: @headers
    assert_response :success

    # Metrics
    get metrics_path, headers: @headers
    assert_response :success

    metric = Metric.order(:id).first
    assert metric, "Expected at least one Metric record/fixture"
    get metric_path(metric), headers: @headers
    assert_response :success

    # Documents
    get documents_path, headers: @headers
    assert_response :success

    document = Document.order(:id).first
    assert document, "Expected at least one Document record/fixture"
    get document_path(document), headers: @headers
    assert_response :success

    # Observations
    get observations_path, headers: @headers
    assert_response :success

    observation = Observation.order(:id).first
    assert observation, "Expected at least one Observation record/fixture"
    get observation_path(observation), headers: @headers
    assert_response :success
  end
end
