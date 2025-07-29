# frozen_string_literal: true

require_relative "middleware/version"
require_relative "middleware/ip_tracker"
require_relative "middleware/user_agent_tracker"
require_relative "middleware/stats_reporter"

module Stats
  module Middleware
    class Error < StandardError; end
  end
end
