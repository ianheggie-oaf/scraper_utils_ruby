# frozen_string_literal: true

require "mechanize"
require "ipaddr"
require "scraper_utils/mechanize_utils/agent_config"

module ScraperUtils
  # Utilities for configuring and using Mechanize for web scraping
  module MechanizeUtils
    PUBLIC_IP_URL = "https://whatismyip.akamai.com/"

    # Creates and configures a Mechanize agent
    # @param (see AgentConfig#initialize)
    # @return [Mechanize] Configured Mechanize agent
    def self.mechanize_agent(**options)
      agent = Mechanize.new
      config = AgentConfig.new(**options)
      config.configure_agent(agent)
      agent.instance_variable_set(:@scraper_utils_config, config)
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
