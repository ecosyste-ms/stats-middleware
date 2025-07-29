# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "stats/middleware"

require "minitest/autorun"
require "date"
require "redis"

# Helper method for capturing output in tests
def capture_io
  original_stdout = $stdout
  original_stderr = $stderr
  captured_stdout = StringIO.new
  captured_stderr = StringIO.new
  $stdout = captured_stdout
  $stderr = captured_stderr
  yield
  [captured_stdout.string, captured_stderr.string]
ensure
  $stdout = original_stdout
  $stderr = original_stderr
end

# Add ActiveSupport-like extensions for days
class Integer
  def days
    self * 24 * 60 * 60
  end
end
