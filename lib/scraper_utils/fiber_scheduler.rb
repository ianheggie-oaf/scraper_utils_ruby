# frozen_string_literal: true

require 'fiber'

module ScraperUtils
  # A utility module for interleaving multiple scraping operations
  # using fibers during connection delay periods. This allows efficient
  # use of wait time by switching between operations.
  module FiberScheduler
    # @return [Array<Fiber>] List of active fibers managed by the scheduler
    def self.registry
      @registry ||= []
    end

    # Checks if the current code is running within a registered fiber
    #
    # @return [Boolean] true if running in a registered fiber, false otherwise
    def self.in_fiber?
      !Fiber.current.nil? && registry.include?(Fiber.current)
    end

    # Gets the authority associated with the current fiber
    #
    # @return [String, nil] the authority name or nil if not in a fiber
    def self.current_authority
      return nil unless in_fiber?
      Fiber.current.instance_variable_get(:@authority)
    end

    # Logs a message, automatically prefixing with authority name if in a fiber
    #
    # @param message [String] the message to log
    # @return [void]
    def self.log(message)
      authority = current_authority
      if authority
        puts "[#{authority}] #{message}"
      else
        puts message
      end
    end

    # Returns a hash of exceptions encountered during processing, indexed by authority
    #
    # @return [Hash{String => Exception}] exceptions by authority
    def self.exceptions
      @exceptions ||= {}
    end

    # Checks if fiber scheduling is currently enabled
    #
    # @return [Boolean] true if enabled, false otherwise
    def self.enabled?
      @enabled ||= false
    end

    # Enables fiber scheduling
    #
    # @return [void]
    def self.enable!
      @enabled = true
    end

    # Disables fiber scheduling
    #
    # @return [void]
    def self.disable!
      @enabled = false
    end

    # Resets the scheduler state by clearing registry, exceptions, and disabling
    # the scheduler. Use this before retrying failed authorities.
    #
    # @return [void]
    def self.reset!
      @registry = []
      @exceptions = {}
      @enabled = false
    end

    # Registers a fiber with a scraping operation for a specific authority
    #
    # @param authority [String] the name of the authority being processed
    # @yield the block containing the scraping operation
    # @return [void]
    def self.register_operation(authority, &block)
      # Automatically enable fiber scheduling when operations are registered
      enable!

      fiber = Fiber.new do
        begin
          block.call
        rescue StandardError => e
          # Store exception against the authority
          exceptions[authority] = e
        ensure
          # Remove itself when done regardless of success/failure
          registry.delete(Fiber.current)
        end
      end

      # Store the authority with the fiber for reference
      fiber.instance_variable_set(:@authority, authority)
      registry << fiber

      # Start the fiber
      fiber.resume
    end

    # Delays the current fiber and potentially runs another one
    # Falls back to regular sleep if fiber scheduling is not enabled
    #
    # @param seconds [Numeric] the number of seconds to delay
    # @return [void]
    def self.delay(seconds)
      # If not running in a fiber context or fiber scheduling is disabled,
      # just do a regular sleep
      current_fiber = Fiber.current
      return sleep(seconds) if !enabled? || !current_fiber || registry.size <= 1

      resume_at = Time.now + seconds

      # Used to compare when other fibers need to be resumed
      current_fiber.instance_variable_set(:@resume_at, resume_at)

      next_fiber = find_earliest_other_fiber
      if next_fiber
        # If the next fiber's wake time has passed or is due before our resume time, resume it
        next_fiber_time = next_fiber.instance_variable_get(:@resume_at)

        if next_fiber_time.nil? || next_fiber_time <= resume_at
          next_fiber.resume
        end
      end

      # After being resumed, check if we need to wait more
      remaining = resume_at - Time.now
      delay(remaining) if remaining.positive?
    end

    # Finds the fiber with the earliest wake-up time, excluding the current fiber
    #
    # @return [Fiber, nil] the fiber with earliest wake-up time or nil if none found
    def self.find_earliest_other_fiber
      earliest_time = nil
      earliest_fiber = nil

      # Shuffle to prevent always picking the same fiber first
      registry.shuffle.each do |fiber|
        next if fiber == Fiber.current

        # If fiber has no wake time, it's ready now
        return fiber unless fiber.instance_variable_defined?(:@resume_at)

        resume_at = fiber.instance_variable_get(:@resume_at)
        if earliest_time.nil? || resume_at < earliest_time
          earliest_time = resume_at
          earliest_fiber = fiber
        end
      end

      earliest_fiber
    end

    # Mark methods as private
    private_class_method :find_earliest_other_fiber
  end
end
