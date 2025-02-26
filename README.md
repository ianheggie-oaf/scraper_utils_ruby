ScraperUtils (Ruby)
===================

Utilities to help make planningalerts scrapers, especially multis easier to develop, run and debug.

WARNING: This is still under development! Breaking changes may occur in version 0!

## Installation

Add these line to your application's Gemfile:

```ruby
gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"
gem 'scraper_utils'
```

And then execute:

    $ bundle

Or install it yourself for testing:

    $ gem install scraper_utils

## Usage

### Ruby Versions

This gem is designed to be compatible the latest ruby supported by morph.io - other versions may work, but not tested:

* ruby 3.2.2 - requires the `platform` file to contain `heroku_18` in the scraper
* ruby 2.5.8 - `heroku_16` (the default)

### Environment variables

#### `MORPH_AUSTRALIAN_PROXY`

On morph.io set the environment variable `MORPH_AUSTRALIAN_PROXY` to
`http://morph:password@au.proxy.oaf.org.au:8888`
replacing password with the real password.
Alternatively enter your own AUSTRALIAN proxy details when testing.

#### `MORPH_EXPECT_BAD`

To avoid morph complaining about sites that are known to be bad,
but you want them to keep being tested, list them on `MORPH_EXPECT_BAD`, for example:



#### `MORPH_AUTHORITIES`
Optionally filter authorities for multi authority scrapers
via environment variable in morph > scraper > settings or
in your dev environment:

```bash
export MORPH_AUTHORITIES=noosa,wagga
```

### Extra Mechanize options

Add `client_options` to your AUTHORITIES configuration and move any of the following settings into it:

* `timeout: Integer` - Timeout for agent connections
* `australian_proxy: true` - Use the MORPH_AUSTRALIAN_PROXY as proxy
* `disable_ssl_certificate_check: true` - Disabled SSL verification for old / incorrect certificates

You can also add the following to (hopefully) be more acceptable and not be blocked by anti scraping technology:

* `compliant_mode: true` - Comply with recommended headers and behaviour to be more acceptable
* `random_delay: Integer` - Use exponentially weighted random delays to be less Bot like (roughly averaging random_delay
  seconds) - try 10 seconds to start with
* `response_delay: true` - Delay requests based on response time to be kind to overloaded servers

Then adjust your code to accept client_options and pass then through to:
`ScraperUtils::MechanizeUtils.mechanize_agent(client_options || {})`
to receive a `Mexhanize::Agent` configured accordingly.

The delays use a Mechanize hook to wrap all requests so you don't need to do anything else

### Default Configuration

By default, the Mechanize agent is configured with the following settings:

```ruby
ScraperUtils::MechanizeUtils::AgentConfig.configure do |config|
  config.default_timeout = 60
  config.default_compliant_mode = true
  config.default_random_delay = 3
  config.default_response_delay = true
  config.default_disable_ssl_certificate_check = false
  config.default_australian_proxy = false
end
```

You can modify these global defaults before creating any Mechanize agents. These settings will be used for all Mechanize agents created by `ScraperUtils::MechanizeUtils.mechanize_agent` unless overridden by specific options.

### Example updated `scraper.rb` file

Update your `scraper.rb` as per the following example for basic utilities:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH << "./lib"

require "scraper_utils"
require "technology_one_scraper"

# Main Scraper class
class Scraper
  AUTHORITIES = TechnologyOneScraper::AUTHORITIES

  # ADD: attempt argument
  def scrape(authorities, attempt)
    exceptions = {}
    # ADD: Report attempt number
    authorities.each do |authority_label|
      puts "\nCollecting feed data for #{authority_label}, attempt: #{attempt}..."

      begin
        # REPLACE:
        # TechnologyOneScraper.scrape(authority_label) do |record|
        #   record["authority_label"] = authority_label.to_s
        #   TechnologyOneScraper.log(record)
        #   ScraperWiki.save_sqlite(%w[authority_label council_reference], record)
        # end
        # WITH:
        ScraperUtils::DataQualityMonitor.start_authority(authority_label)
        TechnologyOneScraper.scrape(authority_label) do |record|
          begin
            record["authority_label"] = authority_label.to_s
            ScraperUtils::DbUtils.save_record(record)
          rescue ScraperUtils::UnprocessableRecord => e
            ScraperUtils::DataQualityMonitor.log_unprocessable_record(e, record)
            exceptions[authority_label] = e
          end
        end
        # END OF REPLACE
      end
      rescue StandardError => e
        warn "#{authority_label}: ERROR: #{e}"
        warn e.backtrace
        exceptions[authority_label] = e
      end
    end
    exceptions
  end


  def self.selected_authorities
    ScraperUtils::AuthorityUtils.selected_authorities(AUTHORITIES.keys)
  end

  def self.run(authorities)
    puts "Scraping authorities: #{authorities.join(', ')}"
    start_time = Time.now
    exceptions = scrape(authorities, 1)
    # Set start_time and attempt to the call above and log run below
    ScraperUtils::LogUtils.log_scraping_run(
      start_time,
      1,
      authorities,
      exceptions
    )

    unless exceptions.empty?
      puts "\n***************************************************"
      puts "Now retrying authorities which earlier had failures"
      puts exceptions.keys.join(", ").to_s
      puts "***************************************************"

      start_time = Time.now
      exceptions = scrape(exceptions.keys, 2)
      # Set start_time and attempt to the call above and log run below
      ScraperUtils::LogUtils.log_scraping_run(
        start_time,
        2,
        authorities,
        exceptions
      )
    end

    # Report on results, raising errors for unexpected conditions
    ScraperUtils::LogUtils.report_on_results(authorities, exceptions)
  end
end

if __FILE__ == $PROGRAM_NAME
  # Default to list of authorities we can't or won't fix in code, explain why
  # wagga: url redirects and then reports Application error

  ENV["MORPH_EXPECT_BAD"] ||= "wagga"
  Scraper.run(Scraper.selected_authorities)
end
```

Then deeper in your code update:

* DROPPED: Change scrape to accept a `use_proxy` flag and return an `unprocessable` flag
* it should rescue ScraperUtils::UnprocessableRecord thrown deeper in the scraping code and
  set and yield unprocessable eg: `TechnologyOneScraper.scrape(use_proxy, authority_label) do |record, unprocessable|`

```ruby
require "scraper_utils"
#...
module TechnologyOneScraper
  # Note the extra parameter: use_proxy
  def self.scrape(authority, use_proxy: false)
    raise "Unexpected authority: #{authority}" unless AUTHORITIES.key?(authority)

    scrape_period(use_proxy: use_proxy, **AUTHORITIES[authority]) do |record, unprocessable|
      yield record, unprocessable
    end
  end

  # ... rest of code ...

  # Note the extra parameters: use_proxy and timeout
  def self.scrape_period(url:, period:, webguest: "P1.WEBGUEST",
                         use_proxy: false, client_options: {}
  )
    agent = ScraperUtils::MechanizeUtils.mechanize_agent(use_proxy:use_proxy, **client_options)

    # ... rest of code ...

    # Update yield to return unprocessable as well as record

  end

  # ... rest of code ...
end
```

### Debugging Techniques

The following code will print dbugging info if you set:

```bash
export DEBUG=1
```

Add the following immediately before requesting or examining pages

```ruby
require 'scraper_utils'

# Debug an HTTP request
ScraperUtils::DebugUtils.debug_request(
  "GET",
  "https://example.com/planning-apps",
  parameters: { year: 2023 },
  headers: { "Accept" => "application/json" }
)

# Debug a web page
ScraperUtils::DebugUtils.debug_page(page, "Checking search results page")

# Debug a specific page selector
ScraperUtils::DebugUtils.debug_selector(page, '.results-table', "Looking for development applications")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake test` to run the tests.

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version, update the version number in `version.rb`, and
then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem` file
to [rubygems.org](https://rubygems.org).

NOTE: You need to use ruby 3.2.2 instead of 2.5.8 to release to OTP protected accounts.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ianheggie-oaf/scraper_utils

CHANGELOG.md is maintained by the author aiming to follow https://github.com/vweevers/common-changelog

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

