# frozen_string_literal: true

require 'mechanize'

module ScraperUtils
  # Utilities for configuring and using Mechanize for web scraping
  module MechanizeUtils
    PUBLIC_IP_URL = "https://whatismyip.akamai.com/"

    # Creates and configures a Mechanize agent with optional proxy and timeout
    #
    # @param timeout [Integer, nil] Timeout for agent connections
    # @param australian_proxy [Boolean] Whether to use an Australian proxy
    # @return [Mechanize] Configured Mechanize agent
    def self.mechanize_agent(timeout: nil, use_proxy: true)
      agent = Mechanize.new
      agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
      use_proxy &&= !ScraperUtils.australian_proxy.to_s.empty?
      if use_proxy
        # On morph.io set the environment variable MORPH_AUSTRALIAN_PROXY to
        # http://morph:password@au.proxy.oaf.org.au:8888 replacing password with
        # the real password.
        agent.agent.set_proxy(ScraperUtils.australian_proxy)
      end
      if timeout
        agent.open_timeout = timeout
        agent.read_timeout = timeout
      end
      public_ip(agent) if use_proxy
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
