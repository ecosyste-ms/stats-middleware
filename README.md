# Stats::Middleware

[![Gem Version](https://badge.fury.io/rb/stats-middleware.svg)](https://badge.fury.io/rb/stats-middleware)
[![Ruby](https://github.com/ecosyste-ms/stats-middleware/actions/workflows/ruby.yml/badge.svg)](https://github.com/ecosyste-ms/stats-middleware/actions/workflows/ruby.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A collection of Rack middleware components for tracking API usage statistics including user agent and IP address data with Redis storage.

This gem was extracted from and built for [Ecosyste.ms](https://ecosyste.ms), an open source platform for monitoring and understanding the health and sustainability of open source software ecosystems.

## Features

- **IP Address Tracking**: Track unique IP addresses making API requests
- **User Agent Tracking**: Monitor user agents accessing your API
- **Redis Storage**: Efficient storage using Redis sorted sets with automatic expiration
- **Configurable**: Flexible configuration options for different use cases
- **Error Resilient**: Redis errors don't break requests - they're logged instead
- **Smart IP Detection**: Properly handles Cloudflare and proxy headers

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'stats-middleware'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install stats-middleware
```

## Usage

### Basic Rails Configuration

Add the middleware to your Rails application in `config/application.rb`:

```ruby
class Application < Rails::Application
  # Track IP addresses for API requests
  config.middleware.use Stats::Middleware::IpTracker, redis: REDIS
  
  # Track user agents for API requests  
  config.middleware.use Stats::Middleware::UserAgentTracker, redis: REDIS
end
```

### Configuration Options

Both middleware classes accept the following options:

```ruby
config.middleware.use Stats::Middleware::IpTracker,
  redis: redis_instance,                    # Redis client instance
  path_filter: ->(path) { path.start_with?('/api/') }, # Custom path filtering
  logger: Rails.logger,                     # Custom logger
  expiry_days: 31                          # Redis key expiration in days

config.middleware.use Stats::Middleware::UserAgentTracker,
  redis: redis_instance,
  path_filter: ->(path) { path.start_with?('/api/') },
  logger: Rails.logger,
  expiry_days: 31,
  redis_key_prefix: 'api_requests'         # Custom Redis key prefix
```

### IP Address Tracking

The `IpTracker` middleware:
- Stores IP addresses in Redis sorted sets with daily keys: `api_requests:ips:YYYY-MM-DD`
- Handles Cloudflare's `CF-Connecting-IP` header
- Supports `X-Forwarded-For` headers for proxy/load balancer setups
- Increments counters for repeated requests from the same IP

### User Agent Tracking

The `UserAgentTracker` middleware:
- Stores user agents in Redis sorted sets with daily keys: `api_requests:YYYY-MM-DD`
- Tracks full user agent strings with request counts
- Handles missing user agent headers gracefully

### Redis Data Structure

Data is stored in Redis sorted sets where:
- **Key**: Daily timestamp (e.g., `api_requests:ips:2025-07-29`)
- **Member**: IP address or user agent string
- **Score**: Number of requests

Example Redis commands to view data:
```redis
# View top IPs for today
ZREVRANGE api_requests:ips:2025-07-29 0 10 WITHSCORES

# View top user agents for today  
ZREVRANGE api_requests:2025-07-29 0 10 WITHSCORES
```

### Non-Rails Usage

For non-Rails Rack applications:

```ruby
require 'stats/middleware'

use Stats::Middleware::IpTracker, redis: Redis.new
use Stats::Middleware::UserAgentTracker, redis: Redis.new
```

## Statistics Reporting

The gem includes a `StatsReporter` class for generating usage reports and rake tasks for easy access.

### Using the StatsReporter Class

```ruby
require 'stats/middleware'

reporter = Stats::Middleware::StatsReporter.new(redis: REDIS)

# Get raw statistics data
stats = reporter.summary(days: 30)
puts stats[:user_agents] # Hash of user agents with request counts
puts stats[:ips]         # Hash of IPs with request counts

# Display formatted summary
reporter.display_summary(days: 7, limit: 10)
```

### Rake Tasks

The gem provides several rake tasks for viewing statistics:

```bash
# Display summary for past 30 days (default)
rake stats_middleware:summary

# Display summary for specific number of days
rake stats_middleware:summary[7]

# Display detailed summary with multiple time periods (3, 7, 30 days)
rake stats_middleware:detailed_summary

# Export statistics to JSON file
rake stats_middleware:export[30,my_stats.json]
```

**Note**: These rake tasks require a `REDIS` constant to be defined in your application.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ecosyste-ms/stats-middleware. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ecosyste-ms/stats-middleware/blob/main/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Stats::Middleware project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ecosyste-ms/stats-middleware/blob/main/CODE_OF_CONDUCT.md).
