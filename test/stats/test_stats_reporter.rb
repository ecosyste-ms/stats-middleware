# frozen_string_literal: true

require "test_helper"

class Stats::TestStatsReporter < Minitest::Test
  def setup
    @redis = Minitest::Mock.new
    @reporter = Stats::Middleware::StatsReporter.new(redis: @redis)
  end

  def test_summary_collects_data_from_multiple_days
    # Mock Redis calls for 3 days
    3.times do |i|
      date = (Date.today - i).to_s
      ua_key = "api_requests:#{date}"
      ip_key = "api_requests:ips:#{date}"
      
      @redis.expect(:exists?, true, [ua_key])
      @redis.expect(:zrevrange, [['Chrome', 10], ['Firefox', 5]]) do |key, start, stop, options|
        key == ua_key && start == 0 && stop == -1 && options[:with_scores] == true
      end
      
      @redis.expect(:exists?, true, [ip_key])
      @redis.expect(:zrevrange, [['192.168.1.1', 8], ['10.0.0.1', 3]]) do |key, start, stop, options|
        key == ip_key && start == 0 && stop == -1 && options[:with_scores] == true
      end
    end

    result = @reporter.summary(days: 3)
    @redis.verify

    assert_equal 30, result[:user_agents]['Chrome'] # 10 * 3
    assert_equal 15, result[:user_agents]['Firefox'] # 5 * 3
    assert_equal 24, result[:ips]['192.168.1.1'] # 8 * 3
    assert_equal 9, result[:ips]['10.0.0.1'] # 3 * 3
    assert_equal 3, result[:days]
  end

  def test_summary_handles_missing_keys
    date = Date.today.to_s
    ua_key = "api_requests:#{date}"
    ip_key = "api_requests:ips:#{date}"
    
    @redis.expect(:exists?, false, [ua_key])
    @redis.expect(:exists?, false, [ip_key])

    result = @reporter.summary(days: 1)
    @redis.verify

    assert_empty result[:user_agents]
    assert_empty result[:ips]
    assert_equal 1, result[:days]
  end

  def test_summary_with_custom_redis_key_prefix
    reporter = Stats::Middleware::StatsReporter.new(redis: @redis, redis_key_prefix: 'custom_stats')
    
    date = Date.today.to_s
    ua_key = "custom_stats:#{date}"
    ip_key = "custom_stats:ips:#{date}"
    
    @redis.expect(:exists?, true, [ua_key])
    @redis.expect(:zrevrange, [['Safari', 7]]) do |key, start, stop, options|
      key == ua_key && start == 0 && stop == -1 && options[:with_scores] == true
    end
    
    @redis.expect(:exists?, true, [ip_key])
    @redis.expect(:zrevrange, [['203.0.113.1', 7]]) do |key, start, stop, options|
      key == ip_key && start == 0 && stop == -1 && options[:with_scores] == true
    end

    result = reporter.summary(days: 1)
    @redis.verify

    assert_equal 7, result[:user_agents]['Safari']
    assert_equal 7, result[:ips]['203.0.113.1']
  end

  def test_summary_report_returns_formatted_string
    # Mock the summary method to return test data
    test_data = {
      user_agents: {'Chrome' => 100, 'Firefox' => 50},
      ips: {'192.168.1.1' => 75, '10.0.0.1' => 25},
      days: 7
    }
    
    @reporter.stub(:summary, test_data) do
      output = @reporter.summary_report(days: 7, limit: 5)
      
      assert_includes output, "API Usage Statistics Summary"
      assert_includes output, "Past 7 days"
      assert_includes output, "Top User Agents:"
      assert_includes output, "Chrome"
      assert_includes output, "100 requests"
      assert_includes output, "Top IP Addresses:"
      assert_includes output, "192.168.1.1"
      assert_includes output, "75 requests"
      assert_includes output, "Total unique user agents: 2"
      assert_includes output, "Total unique IPs: 2"
      assert_includes output, "Total API requests: 150"
    end
  end

  def test_summary_report_handles_empty_data
    test_data = {
      user_agents: {},
      ips: {},
      days: 1
    }
    
    @reporter.stub(:summary, test_data) do
      output = @reporter.summary_report(days: 1)
      
      assert_includes output, "No user agent data available"
      assert_includes output, "No IP data available"
      assert_includes output, "Total unique user agents: 0"
      assert_includes output, "Total unique IPs: 0"
      assert_includes output, "Total API requests: 0"
    end
  end

  def test_summary_report_truncates_long_user_agents
    test_data = {
      user_agents: {'a' * 60 => 10},
      ips: {'192.168.1.1' => 10},
      days: 1
    }
    
    @reporter.stub(:summary, test_data) do
      output = @reporter.summary_report(days: 1)
      
      assert_includes output, "#{('a' * 47)}..."
      refute_includes output, 'a' * 60
    end
  end
end