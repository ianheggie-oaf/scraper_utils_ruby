# frozen_string_literal: true

# Checks robots.txt for relevant lines
class RobotsChecker
  # Initialize with full user agent string like:
  # "Mozilla/5.0 (compatible; ScraperUtils/0.1.0 2025-02-22; +https://github.com/ianheggie-oaf/scraper_utils)"
  # Will extract the bot name part (e.g. "ScraperUtils/0.1.0") to check against robots.txt
  #
  # robots.txt matches would include:
  # User-agent: ScraperUtils/0.1.0
  # User-agent: ScraperUtils/
  # User-agent: ScraperUtils
  # But NOT:
  # User-agent: *
  def initialize(user_agent)
    @user_agent = (
      user_agent.match(/compatible;\s+([^;\s]+)/i)&.[](1)&.strip ||
        user_agent
    )&.downcase
    if ENV["DEBUG"]
      puts "Checking robots.txt for user agent prefix: #{@user_agent} (case insensitive)"
    end
    @rules = {} # domain -> {rules: [], delay: int}
    @delay = nil # Delay from last robots.txt check
  end

  # Check if a URL is allowed based on robots.txt rules specific to our user agent
  # Will ignore generic '*' rules but respect any crawl-delay directives
  # The crawl_delay method will return delay applicable to the last URL checked
  # @param url [String] The full URL to check
  # @return [Boolean] true if allowed or robots.txt unavailable, false if specifically blocked
  def allowed?(url)
    uri = URI(url)
    domain = "#{uri.scheme}://#{uri.host}"
    path = uri.path

    # Get or fetch robots.txt rules
    rules = get_rules(domain)
    return true unless rules # If we can't get robots.txt, assume allowed

    # Store any delay found (specific to us or generic)
    # Will be available via crawl_delay method after this check
    @delay = rules[:our_delay] || rules[:generic_delay]

    # Only check disallow rules if our specific user agent is mentioned
    if rules[:our_rules].any?
      # We were mentioned specifically, follow our rules
      rules[:our_rules].each do |rule|
        return false if path&.start_with?(rule)
      end
    end

    true # Allow by default
  end

  # Returns the crawl delay (if any) that applied to the last URL checked
  # Should be called after allowed? to get relevant delay
  # @return [Integer, nil] The delay in seconds, or nil if no delay specified
  def crawl_delay
    @delay
  end

  # Fetch and cache robots.txt content for a domain
  # @param domain [String] The domain including protocol (e.g. "https://example.com")
  # @return [Hash, nil] Parsed rules or nil if robots.txt unavailable
  def get_rules(domain)
    return @rules[domain] if @rules.key?(domain)

    begin
      response = Net::HTTP.get_response(URI("#{domain}/robots.txt"))
      return nil unless response.code.start_with?("2") # 2xx response

      rules = parse_robots_txt(response.body)
      @rules[domain] = rules
      rules
    rescue StandardError => e
      puts "Warning: Failed to fetch robots.txt for #{domain}: #{e.message}" if $DEBUG
      nil
    end
  end

  # Parse robots.txt content into structured rules
  # Only collects rules for our specific user agent and generic crawl-delay
  # @param content [String] The robots.txt content
  # @return [Hash] Hash containing :our_rules, :our_delay and :generic_delay
  def parse_robots_txt(content)
    our_rules = []
    our_delay = nil
    generic_delay = nil
    current_agent = nil
    content.each_line do |line|
      line = line.strip.downcase

      if line.start_with?("user-agent:")
        agent = line.split(":", 2).last.strip
        current_agent = agent
        next
      end

      next unless current_agent # Skip rules before first user-agent

      if line.start_with?("disallow:")
        path = line.split(":", 2).last.strip
        next if path.empty?

        our_rules << path if @user_agent.downcase.start_with?(current_agent)
      elsif line.start_with?("crawl-delay:")
        delay = line.split(":", 2).last.strip.to_i
        if delay.positive?
          # Changed to prefix match
          if current_agent.start_with?(@user_agent.downcase)
            our_delay = delay
          elsif current_agent == "*"
            generic_delay = delay
          end
        end
      end
    end

    {
      our_rules: our_rules, # Disallow rules specific to our user agent
      our_delay: our_delay, # Crawl-delay specific to our user agent
      generic_delay: generic_delay # Generic crawl-delay (user-agent: *)
    }
  end
end
