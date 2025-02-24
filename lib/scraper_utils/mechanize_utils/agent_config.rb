# frozen_string_literal: true

require "mechanize"
require "ipaddr"

module ScraperUtils
  module MechanizeUtils
    # Configuration and hooks for Mechanize agent
    class AgentConfig
      # @return [RobotsChecker] Checker for robots.txt rules
      attr_reader :robots_checker
      # @return [AdaptiveDelay] Handler for adaptive delays
      attr_reader :adaptive_delay
      # @return [Boolean] Whether compliant mode is enabled
      attr_reader :compliant_mode
      # @return [Integer, nil] Timeout in seconds for connections
      attr_reader :timeout
      # @return [Integer, nil] Target random delay in seconds
      attr_reader :random_delay
      # @return [Boolean] Whether to use response-based delays
      attr_reader :response_delay
      # @return [Boolean] Whether to disable SSL certificate verification
      attr_reader :disable_ssl_certificate_check
      # @return [String] User agent string
      attr_reader :user_agent
      # @return [Time] When the current request started
      attr_reader :connection_started_at

      # Creates configuration for a Mechanize agent
      # @param use_proxy [Boolean] Use the Australian proxy if available
      # @param timeout [Integer, nil] Timeout for agent connections
      # @param compliant_mode [Boolean] Comply with headers and robots.txt
      # @param random_delay [Integer, nil] Average random delay in seconds
      # @param response_delay [Boolean] Delay based on response times
      # @param disable_ssl_certificate_check [Boolean] Skip SSL verification
      # @param australian_proxy [Boolean] Flag for proxy preference
      def initialize(use_proxy: false,
                     timeout: nil,
                     compliant_mode: false,
                     random_delay: nil,
                     response_delay: false,
                     disable_ssl_certificate_check: false,
                     australian_proxy: false)
        @use_proxy = use_proxy && australian_proxy && !ScraperUtils.australian_proxy.to_s.empty?
        @timeout = timeout
        @compliant_mode = compliant_mode
        @random_delay = random_delay
        @response_delay = response_delay
        @disable_ssl_certificate_check = disable_ssl_certificate_check

        # Calculate random delay parameters
        target_delay = random_delay || 10
        @min_random = Math.sqrt(target_delay * 3.0 / 13.0)
        @max_random = 3 * @min_random

        version = ScraperUtils::VERSION
        today = Date.today.strftime("%Y-%m-%d")
        @user_agent = "Mozilla/5.0 (compatible; ScraperUtils/#{version} #{today}; +https://github.com/ianheggie-oaf/scraper_utils)"

        @robots_checker = RobotsChecker.new(@user_agent)
        @adaptive_delay = AdaptiveDelay.new
        display_options
      end

      # Configures a Mechanize agent with these settings
      # @param agent [Mechanize] The agent to configure
      # @return [void]
      def configure_agent(agent)
        agent.verify_mode = OpenSSL::SSL::VERIFY_NONE if disable_ssl_certificate_check
        agent.user_agent = user_agent if compliant_mode

        if @use_proxy
          agent.agent.set_proxy(ScraperUtils.australian_proxy)
          agent.request_headers ||= {}
          agent.request_headers["Accept-Language"] = "en-AU,en-US;q=0.9,en;q=0.8"
        end

        if timeout
          agent.open_timeout = timeout
          agent.read_timeout = timeout
        end

        agent.pre_connect_hooks << method(:pre_connect_hook)
        agent.post_connect_hooks << method(:post_connect_hook)

        verify_proxy(agent) if @use_proxy
      end

      private

      def pre_connect_hook(_agent, request)
        @connection_started_at = Time.now
        puts "Pre Connect request: #{request.inspect}" if ENV["DEBUG"]

        url = request.uri.to_s
        if compliant_mode && !url.empty?
          unless robots_checker.allowed?(url)
            raise ScraperUtils::UnprocessableSite,
                  "URL not allowed by robots.txt specific rules: #{url}"
          end
        end
      end

      def post_connect_hook(_agent, uri, response, _body)
        raise ArgumentError, "URI must be present in post-connect hook" unless uri

        response_time = Time.now - connection_started_at
        puts "Post Connect uri: #{uri.inspect}, response: #{response.inspect}" if ENV["DEBUG"]

        domain = "#{uri.scheme}://#{uri.host}"
        delay = [
          robots_checker.crawl_delay,
          (response_delay ? adaptive_delay.next_delay(domain, response_time) : 0.0),
          (random_delay ? rand(@min_random..@max_random) ** 2 : 0.0)
        ].compact.max

        if delay&.positive?
          puts "Delaying #{delay.round(3)} seconds" if ENV["DEBUG"]
          sleep(delay)
        end

        response
      end

      def verify_proxy(agent)
        my_ip = MechanizeUtils.public_ip(agent)
        begin
          IPAddr.new(my_ip)
          puts "Proxy check PASSED with public IP: #{my_ip}"
        rescue IPAddr::InvalidAddressError => e
          raise "Invalid public IP address returned by proxy check: #{my_ip.inspect}: #{e}"
        end
      end

      def display_options
        display_args = []
        display_args << "timeout=#{options[:timeout]}" if options[:timeout]
        if options[:use_proxy]
          extra = if !options[:australian_proxy]
                    " (but australian_proxy not set for authority)"
                  elsif ScraperUtils.australian_proxy.to_s.empty?
                    " (but #{ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR} env var is blank)"
                  end
          display_args << "use_proxy#{extra}"
        end
        display_args << "compliant_mode" if options[:compliant_mode]
        display_args << "random_delay=#{options[:random_delay]}" if options[:random_delay]
        display_args << "response_delay" if options[:response_delay]
        display_args << "disable_ssl_certificate_check" if options[:disable_ssl_certificate_check]
        display_args << "australian_proxy not used" if options[:australian_proxy] && !options[:use_proxy]
        puts "Created Mechanize agent with #{display_args.join(', ')}"
      end
    end
  end
