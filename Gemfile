source "https://rubygems.org"

platform = case
           when Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.0.0') then :heroku_16
           when Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.3.0') then :heroku_18
           else nil # more recent platform
           end

ruby case platform
     when :heroku_16 then '~> 2.5.8'
     when :heroku_18 then '~> 3.2.2'
     else '~> 3.3.7'
     end

gem "mechanize", platform && (platform == :heroku_16 ? "~> 2.7.0" : "~> 2.8.5")
gem "nokogiri", platform && (platform == :heroku_16 ? "~> 1.11.2" : "~> 1.15.0")
gem "sqlite3", platform && (platform == :heroku_16 ? "~> 1.4.0" : "~> 1.6.3")

# Unable to list in gemspec - Include it in your projects Gemfile when using this gem
gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"

# development and test test gems
gem "rake", platform && (platform == :heroku_16 ? "~> 12.3.3" : "~> 13.0")
gem "rspec", platform && (platform == :heroku_16 ? "~> 3.9.0" : "~> 3.12")
gem "rubocop", platform && (platform == :heroku_16 ? "~> 0.80.0" : "~> 1.57")
gem "simplecov", platform && (platform == :heroku_16 ? "~> 0.18.0" : "~> 0.22.0")
# gem "simplecov-console" listed in gemspec
gem "webmock", platform && (platform == :heroku_16 ? "~> 3.14.0" : "~> 3.19.0")

gemspec
