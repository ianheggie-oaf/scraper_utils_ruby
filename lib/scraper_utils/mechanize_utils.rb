# frozen_string_literal: true

require "mechanize"

module ScraperUtils
  # Utilities for configuring and using Mechanize for web scraping
  module MechanizeUtils
    PUBLIC_IP_URL = "https://whatismyip.akamai.com/"

    # Creates and configures a Mechanize agent with optional proxy and timeout
    #
    # @param use_proxy [True] Use the Australian proxy
    # @param timeout [Integer, nil] Timeout for agent connections
    # @param compliant_mode [Boolean] Comply with recommended headers and behaviour
    #        to be more acceptable
    # @param random_delay [Integer] Use exponentially weighted random delayed
    #        (roughly averaging random_delay seconds)
    # @param response_delay [True] Delay requests based on response time to be kind to
    #        overloaded servers
    # @param disable_ssl_certificate_check [True] Disabled SSL verification for old /
    #        incorrect certificates
    # @param australian_proxy [True] Flags the Australian proxy should be used if available,
    #        and not 3rd attempt
    # @return [Mechanize] Configured Mechanize agent
    def self.mechanize_agent(use_proxy: false,
                             timeout: nil,
                             compliant_mode: false,
                             random_delay: nil,
                             response_delay: false,
                             disable_ssl_certificate_check: false,
                             australian_proxy: false)
      display_args = []
      display_args << "timeout=#{timeout}" if timeout
      display_args << "use_proxy" if use_proxy
      display_args << "compliant_mode" if compliant_mode
      display_args << "random_delay=#{random_delay}" if random_delay
      display_args << "response_delay" if response_delay
      display_args << "disable_ssl_certificate_check" if disable_ssl_certificate_check
      display_args << "australian_proxy not used" if australian_proxy && !use_proxy
      puts "Created Mechanize agent with #{display_args.join(', ')}}"

      agent = Mechanize.new
      agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
      agent.verify_mode = OpenSSL::SSL::VERIFY_NONE if disable_ssl_certificate_check
      use_proxy &&= !ScraperUtils.australian_proxy.to_s.empty?
      if use_proxy
        # On morph.io set the environment variable MORPH_AUSTRALIAN_PROXY to
        # http://morph:password@au.proxy.oaf.org.au:8888 replacing password with
        # the real password.
        agent.agent.set_proxy(ScraperUtils.australian_proxy)
        agent.request_headers ||= {}
        agent.request_headers["Accept-Language"] = "en-AU,en-US;q=0.9,en;q=0.8"
      end
      if timeout
        agent.open_timeout = timeout
        agent.read_timeout = timeout
      end

      public_ip(agent) if use_proxy

      version = ScraperUtils::VERSION
      today = Date.today.strftime("%Y-%m-%d")
      user_agent = "Mozilla/5.0 (compatible; ScraperUtils/#{version} #{today}; +https://github.com/openaustralia/scraperwiki-library)"
      agent.user_agent = user_agent if compliant_mode

      # Calculating a rand that when
      target_delay = random_delay || 10
      min_random = Math.sqrt(target_delay * 3.0 / 13.0)
      max_random = 3 * min_random

      robots_checker = RobotsChecker.new(user_agent)
      adaptive_delay = AdaptiveDelay.new

      # Add pre-request hook to check robots.txt
      agent.pre_connect_hooks << lambda do |_, request|
        url = request.uri.to_s
        unless robots_checker.allowed?(url) && compliant_mode
          raise ScraperUtils::UnprocessableSite,
                "URL not allowed by robots.txt specific rules: #{url}"
        end

        domain = "#{request.uri.scheme}://#{request.uri.host}"
        start_time = Time.now
        response = yield # Let the request happen
        response_time = Time.now - start_time

        delay = [
          robots_checker.crawl_delay,
          (response_delay ? adaptive_delay.next_delay(domain, response_time) : 0.0),
          (random_delay ? rand(min_random..max_random)**2 : 0.0)
        ].compact.max

        if delay&.positive?
          puts "Delaying #{delay.round(3)} seconds" if ENV["DEBUG"]
          sleep(delay)
        end
        response
      end

      agent
    end

    # Returns if the Mechanize agent is using the proxy
    def self.using_proxy?(agent)
      !agent.agent.proxy_uri.nil?
    end

    # Checks if a page indicates a maintenance mode
    #
    # @param page [Mechanize::Page] The web page to check
    # @return [String, nil] Maintenance message if found, otherwise nil
    def self.find_maintenance_message(page)
      # Use Nokogiri for parsing because earlier versions of Mechanize
      # do not support the .search method on page objects
      doc = Nokogiri::HTML(page.body)
      doc.css("h1, title").each do |element|
        text = element.inner_text
        return "Maintenance: #{text}" if text&.match?(/maintenance/i)
      end

      # Not in maintenance mode
      nil
    end

    # Retrieves and logs the public IP address
    #
    # @param agent [Mechanize] Mechanize agent to use for IP lookup
    # @param force [Boolean] Force a new IP lookup, bypassing cache
    # @return [String] The public IP address
    def self.public_ip(agent, force: false)
      @public_ip = nil if force
      @public_ip ||=
        begin
          ip = agent.get(PUBLIC_IP_URL).body.strip
          puts "Public IP: #{ip}"
          ip
        end
    end
  end
end
