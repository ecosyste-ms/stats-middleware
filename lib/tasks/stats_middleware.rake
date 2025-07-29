# frozen_string_literal: true

require 'stats/middleware'

namespace :stats_middleware do
  desc "Display API usage statistics summary"
  task :summary, [:days] => :environment do |task, args|
    days = args[:days]&.to_i || 30
    
    unless defined?(REDIS)
      puts "Error: REDIS constant not defined. Please ensure Redis is configured in your application."
      puts "Example: REDIS = Redis.new(url: ENV['REDIS_URL'])"
      exit 1
    end
    
    reporter = Stats::Middleware::StatsReporter.new(redis: REDIS)
    puts reporter.summary_report(days: days)
  end

  desc "Display API usage statistics for multiple time periods"
  task :detailed_summary => :environment do
    unless defined?(REDIS)
      puts "Error: REDIS constant not defined. Please ensure Redis is configured in your application."
      exit 1
    end
    
    reporter = Stats::Middleware::StatsReporter.new(redis: REDIS)
    
    puts "=" * 80
    puts "API Usage Statistics - Detailed Summary"
    puts "=" * 80
    
    [3, 7, 30].each do |days|
      puts "\nPast #{days} Days:"
      puts "-" * 40
      puts reporter.summary_report(days: days)
    end
  end

  desc "Export API usage statistics to JSON"
  task :export, [:days, :output_file] => :environment do |task, args|
    days = args[:days]&.to_i || 30
    output_file = args[:output_file] || "api_stats_#{Date.today}_#{days}days.json"
    
    unless defined?(REDIS)
      puts "Error: REDIS constant not defined. Please ensure Redis is configured in your application."
      exit 1
    end
    
    require 'json'
    
    reporter = Stats::Middleware::StatsReporter.new(redis: REDIS)
    stats = reporter.summary(days: days)
    
    export_data = {
      generated_at: Time.now.iso8601,
      period_days: days,
      summary: {
        total_unique_user_agents: stats[:user_agents].keys.count,
        total_unique_ips: stats[:ips].keys.count,
        total_requests: stats[:user_agents].values.sum
      },
      user_agents: stats[:user_agents].sort_by { |_, count| -count },
      ips: stats[:ips].sort_by { |_, count| -count }
    }
    
    File.write(output_file, JSON.pretty_generate(export_data))
    puts "Statistics exported to: #{output_file}"
    puts "Period: #{days} days"
    puts "Total requests: #{export_data[:summary][:total_requests]}"
  end
end