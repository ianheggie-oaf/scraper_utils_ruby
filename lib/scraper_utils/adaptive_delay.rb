# frozen_string_literal: true

# Manages calculating the next delay based on previous response times
class AdaptiveDelay
  DEFAULT_TIMEOUT = 30 # Presumed default timeout for Mechanize

  def initialize(initial_delay: 0.2, timeout: nil)
    @delays = {} # domain -> last delay used
    @initial = initial_delay.to_f # Ensure initial delay is float
    # Use timeout if provided, otherwise Mechanize default
    @max_delay = (timeout || DEFAULT_TIMEOUT) / 2.0
    puts "AdaptiveDelay initialized with max_delay: #{@max_delay}s" if $DEBUG
  end

  def next_delay(domain, response_time)
    current = @delays[domain] || @initial
    delay = ((4.0 * current) + response_time) / 5.0
    delay = delay.clamp(@initial, @max_delay)

    if ENV["DEBUG"] && delay != current
      puts "Adaptive delay for #{domain} changing from #{current.round(2)}s to " \
           "#{delay.round(2)}s (response_time: #{response_time.round(2)}s)"
    end

    @delays[domain] = delay
    delay
  end
end
