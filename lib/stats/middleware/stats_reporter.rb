# frozen_string_literal: true

module Stats
  module Middleware
    class StatsReporter
      def initialize(redis:, redis_key_prefix: 'api_requests')
        @redis = redis
        @redis_key_prefix = redis_key_prefix
      end

      def summary(days: 30)
        user_agents = {}
        ips = {}
        
        # Collect data for the specified number of days
        days.times do |i|
          date = (Date.today - i).to_s
          
          # Collect user agents
          ua_key = "#{@redis_key_prefix}:#{date}"
          if @redis.exists?(ua_key)
            @redis.zrevrange(ua_key, 0, -1, with_scores: true).each do |agent, count|
              user_agents[agent] ||= 0
              user_agents[agent] += count.to_i
            end
          end
          
          # Collect IPs
          ip_key = "#{@redis_key_prefix}:ips:#{date}"
          if @redis.exists?(ip_key)
            @redis.zrevrange(ip_key, 0, -1, with_scores: true).each do |ip, count|
              ips[ip] ||= 0
              ips[ip] += count.to_i
            end
          end
        end
        
        {
          user_agents: user_agents,
          ips: ips,
          days: days
        }
      end

      def summary_report(days: 30, limit: 10)
        stats = summary(days: days)
        
        output = []
        output << "=" * 80
        output << "API Usage Statistics Summary"
        output << "=" * 80
        output << "Period: Past #{days} days"
        output << "-" * 40
        
        output << format_user_agents(stats[:user_agents], limit: limit)
        output << format_ips(stats[:ips], limit: limit)
        output << format_totals(stats[:user_agents], stats[:ips])
        
        output << "=" * 80
        output.join("\n")
      end

      def display_summary(days: 30, limit: 10)
        puts summary_report(days: days, limit: limit)
      end

      private

      def format_user_agents(user_agents, limit: 10)
        output = ["\nTop User Agents:"]
        if user_agents.empty?
          output << "  No user agent data available"
        else
          sorted_agents = user_agents.sort_by { |_, count| -count }.first(limit)
          max_agent_length = sorted_agents.map { |agent, _| agent.length }.max || 0
          max_agent_length = [max_agent_length, 50].min # Cap at 50 chars for display
          
          sorted_agents.each_with_index do |(agent, count), index|
            display_agent = agent.length > 50 ? "#{agent[0..47]}..." : agent
            output << sprintf("  %2d. %-#{max_agent_length}s : %6d requests", index + 1, display_agent, count)
          end
        end
        output.join("\n")
      end

      def format_ips(ips, limit: 10)
        output = ["\nTop IP Addresses:"]
        if ips.empty?
          output << "  No IP data available"
        else
          sorted_ips = ips.sort_by { |_, count| -count }.first(limit)
          max_ip_length = sorted_ips.map { |ip, _| ip.length }.max || 0
          
          sorted_ips.each_with_index do |(ip, count), index|
            output << sprintf("  %2d. %-#{max_ip_length}s : %6d requests", index + 1, ip, count)
          end
        end
        output.join("\n")
      end

      def format_totals(user_agents, ips)
        output = ["\nSummary:"]
        output << "  Total unique user agents: #{user_agents.keys.count}"
        output << "  Total unique IPs: #{ips.keys.count}"
        output << "  Total API requests: #{user_agents.values.sum}"
        output.join("\n")
      end
    end
  end
end