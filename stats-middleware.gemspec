# frozen_string_literal: true

require_relative "lib/stats/middleware/version"

Gem::Specification.new do |spec|
  spec.name = "stats-middleware"
  spec.version = Stats::Middleware::VERSION
  spec.authors = ["Andrew Nesbitt"]
  spec.email = ["andrew@ecosyste.ms"]

  spec.summary = "Rack middleware for tracking user agent and IP statistics"
  spec.description = "A collection of Rack middleware components for tracking API usage statistics including user agent and IP address data with Redis storage."
  spec.homepage = "https://github.com/ecosyste-ms/stats-middleware"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ecosyste-ms/stats-middleware"
  spec.metadata["changelog_uri"] = "https://github.com/ecosyste-ms/stats-middleware/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", ">= 4.0"
  spec.add_dependency "rack", ">= 2.0"
  spec.add_dependency "logger"
end
