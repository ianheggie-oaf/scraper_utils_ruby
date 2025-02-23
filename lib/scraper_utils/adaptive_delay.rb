# frozen_string_literal: true

require 'uri'

# Adapts delays between requests based on server response times. Aims to keep scraper load
# below 20% of server capacity by targeting delays approximately 4 times the response time.
# Uses an exponential moving average to smooth variations in response times.
class AdaptiveDelay
  DEFAULT_MIN_DELAY = 0.0
  DEFAULT_MAX_DELAY = 30.0 # Presumed default timeout for Mechanize

  attr_reader :min_delay, :max_delay

  # Creates a new adaptive delay calculator
  #
  # @param min_delay [Float] Minimum delay between requests in seconds
  # @param max_delay [Float] Maximum delay between requests in seconds
  def initialize(min_delay: DEFAULT_MIN_DELAY, max_delay: DEFAULT_MAX_DELAY)
    @delays = {} # domain -> last delay used
    @min_delay = min_delay.to_f
    @max_delay = max_delay.to_f
    puts "AdaptiveDelay initialized with delays between #{@min_delay} and #{@max_delay} seconds" if ENV['DEBUG']
  end

  # Extracts the scheme and host from a URL to create a domain key
  #
  # @param uri [URI::Generic, String] The URL to extract the domain from
  # @return [String] The domain in the format "scheme://host"
  def domain(uri)
    uri = URI(uri) unless uri.is_a?(URI)
    "#{uri.scheme}://#{uri.host}".downcase
  end

  # Gets the current delay for a domain
  #
  # @param uri [URI::Generic, String] URL to get delay for
  # @return [Float] Current delay for the domain, or min_delay if no delay set
  def delay(uri)
    @delays[domain(uri)] || @min_delay
  end

  # Calculates the next delay based on the response time
  # Uses exponential moving average: delay = (9 * current_delay + 4 * response_time) / 10
  # This targets a delay approximately 4x the response time while smoothing variations
  #
  # @param uri [URI::Generic, String] URL the response came from
  # @param response_time [Float] Time in seconds the server took to respond
  # @return [Float] The calculated delay to use before the next request
  def next_delay(uri, response_time)
    uris_domain = domain(uri)
    # aim at four times response_time, kept within sane values
    value = response_time.clamp(0.0, @max_delay) * 4.0
    current_delay = @delays[uris_domain] || value
    delay = (9.0 * current_delay + value) / 10.0
    delay = delay.clamp(@min_delay, @max_delay)

    if ENV["DEBUG"]
      puts "Adaptive delay for #{uris_domain} updated to " \
             "#{delay.round(2)}s to trend to 4 * response_time(#{response_time.round(2)}s)"
    end

    @delays[uris_domain] = delay
    delay
  end
end
