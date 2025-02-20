# frozen_string_literal: true

require 'mechanize'

module ScraperUtils
  # Utilities for using Mechanize
  module MechanizeUtils
    # Returns an initialized Mechanize agent for Australia sites
    def self.mechanize_agent(timeout, australian_proxy)
      agent = Mechanize.new
      agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
      australian_proxy &&= !ENV["MORPH_AUSTRALIAN_PROXY"].empty?
      if australian_proxy
        # On morph.io set the environment variable MORPH_AUSTRALIAN_PROXY to
        # http://morph:password@au.proxy.oaf.org.au:8888 replacing password with
        # the real password.
        agent.agent.set_proxy(ENV["MORPH_AUSTRALIAN_PROXY"])
      end
      if timeout
        agent.open_timeout = timeout
        agent.read_timeout = timeout
      end
      public_ip(agent) if australian_proxy
      agent
    end

    def self.find_maintenance_message(page)
      # Common maintenance message patterns
      # page_text = page.body.strip
      # matches = page_text.match(/[^<>"]{0,50}(maintenance mode|system[^<>"]*maintenance)[^<>"]{0,50}/i)
      # return "Maintenance: #{matches[0].strip}" if matches

      # Check specific h1/title patterns
      page.search("h1, title").map(&:inner_text).each do |text|
        return "Maintenance: #{text}" if text&.match?(/maintenance/i)
      end

      # Not in maintenance mode
      nil
    end

    def self.public_ip(agent)
      @public_ip ||=
        begin
          ip = agent.get("https://whatismyip.akamai.com/").body.strip
          puts "Public IP: #{ip}"
          ip
        end
    end
  end
end
