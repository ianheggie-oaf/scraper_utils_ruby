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
  #
  # ONLY Crawl-delay from default:
  # User-agent: *
  def initialize(user_agent)
    @user_agent = extract_user_agent(user_agent).downcase
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
    return true if url.nil? || url.empty?

    uri = URI(url)
    domain = "#{uri.scheme}://#{uri.host}"
    path = uri.path || "/"

    # Get or fetch robots.txt rules
    rules = get_rules(domain)
    return true unless rules # If we can't get robots.txt, assume allowed

    # Store any delay found for this domain
    @delay = rules[:our_delay]

    # Check rules specific to our user agent
    !matches_any_rule?(path, rules[:our_rules])
  end

  # Returns the crawl delay (if any) that applied to the last URL checked
  # Should be called after allowed? to get relevant delay
  # @return [Integer, nil] The delay in seconds, or nil if no delay specified
  def crawl_delay
    @delay
  end

  private

  def extract_user_agent(user_agent)
    if user_agent =~ /compatible;\s+([^;\s]+)/i
      $1.strip
    else
      user_agent.strip
    end
  end

  def matches_any_rule?(path, rules)
    rules&.any? { |rule| path.start_with?(rule) }
  end

  def get_rules(domain)
    return @rules[domain] if @rules.key?(domain)

    begin
      response = Net::HTTP.get_response(URI("#{domain}/robots.txt"))
      return nil unless response.code.start_with?("2") # 2xx response

      rules = parse_robots_txt(response.body)
      @rules[domain] = rules
      rules
    rescue StandardError => e
      puts "Warning: Failed to fetch robots.txt for #{domain}: #{e.message}" if ENV["DEBUG"]
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
    current_agent = nil
    is_our_section = false

    content.each_line do |line|
      line = line.strip.downcase
      next if line.empty? || line.start_with?("#")

      if line.start_with?("user-agent:")
        agent = line.split(":", 2).last.strip
        current_agent = agent
        is_our_section = @user_agent.start_with?(current_agent)
        next
      end

      next unless current_agent # Skip rules before first user-agent
      next unless is_our_section # Only process rules for our user agent

      if line.start_with?("disallow:")
        path = line.split(":", 2).last.strip
        our_rules << path unless path.empty?
      elsif line.start_with?("crawl-delay:")
        delay = line.split(":", 2).last.strip.to_i
        our_delay = delay if delay.positive?
      end
    end

    {
      our_rules: our_rules,
      our_delay: our_delay
    }
  end
end
