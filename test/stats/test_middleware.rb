# frozen_string_literal: true

require "test_helper"

class Stats::TestMiddleware < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Stats::Middleware::VERSION
  end

  def test_it_loads_middleware_classes
    assert_equal Stats::Middleware::IpTracker, Stats::Middleware::IpTracker
    assert_equal Stats::Middleware::UserAgentTracker, Stats::Middleware::UserAgentTracker
  end
end
