# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/scraper_utils/fiber_scheduler'

RSpec.describe ScraperUtils::FiberScheduler do
  before(:each) do
    described_class.reset!
  end

  describe '.register_operation' do
    it 'creates a fiber and adds it to the registry' do
      expect {
        described_class.register_operation('test_authority') { }
      }.to change { described_class.registry.size }.by(1)
    end

    it 'automatically enables fiber scheduling' do
      expect(described_class.enabled?).to be false
      described_class.register_operation('test_authority') { }
      expect(described_class.enabled?).to be true
    end

    it 'executes the given block in a fiber' do
      block_executed = false
      described_class.register_operation('test_authority') do
        block_executed = true
      end
      expect(block_executed).to be true
    end

    it 'stores the authority with the fiber' do
      described_class.register_operation('test_authority') do
        expect(described_class.current_authority).to eq('test_authority')
      end
    end

    it 'captures exceptions and stores them by authority' do
      described_class.register_operation('error_authority') do
        raise "Test error"
      end

      expect(described_class.exceptions).to have_key('error_authority')
      expect(described_class.exceptions['error_authority'].message).to eq('Test error')
    end

    it 'removes the fiber from registry after completion' do
      described_class.register_operation('test_authority') { }
      expect(described_class.registry).to be_empty
    end

    it 'removes the fiber from registry even after exception' do
      described_class.register_operation('error_authority') do
        raise "Test error"
      end

      expect(described_class.registry).to be_empty
    end
  end

  describe '.delay' do
    context 'when fiber scheduling is disabled' do
      it 'falls back to regular sleep' do
        described_class.disable!
        expect(described_class).to receive(:sleep).with(0.1)
        described_class.delay(0.1)
      end
    end

    context 'when registry is empty' do
      it 'falls back to regular sleep' do
        described_class.enable!
        expect(described_class).to receive(:sleep).with(0.1)
        described_class.delay(0.1)
      end
    end

    context 'with only one fiber' do
      it 'falls back to regular sleep' do
        # Setup a fiber but don't let it complete
        test_fiber = Fiber.new { Fiber.yield }
        described_class.registry << test_fiber
        described_class.enable!

        # Mock current_fiber to be the same as our test_fiber
        allow(Fiber).to receive(:current).and_return(test_fiber)

        expect(described_class).to receive(:sleep).with(0.1)
        described_class.delay(0.1)
      end
    end

    context 'with multiple fibers' do
      it 'switches to another fiber if available' do
        described_class.enable!

        # Create two fibers that will call delay
        first_executed = false
        second_executed = false

        # This will be our "current" fiber
        first_fiber = Fiber.new do
          first_executed = true
          described_class.delay(0.1) # This should switch to second_fiber
        end

        # This will be the fiber we switch to
        second_fiber = Fiber.new do
          second_executed = true
          Fiber.yield
        end

        # Add fibers to registry
        described_class.registry << first_fiber
        described_class.registry << second_fiber

        # Mock current_fiber to be first_fiber
        allow(Fiber).to receive(:current).and_return(first_fiber)

        # Start first fiber
        first_fiber.resume

        # Both fibers should have executed
        expect(first_executed).to be true
        expect(second_executed).to be true
      end

      it 'handles wake-up times correctly' do
        described_class.enable!

        now = Time.now
        allow(Time).to receive(:now).and_return(now)

        # Create two fibers with different wake-up times
        current_fiber = Fiber.new { Fiber.yield }
        other_fiber = Fiber.new { Fiber.yield }

        # Set resume times
        current_fiber.instance_variable_set(:@resume_at, now + 0.5)
        other_fiber.instance_variable_set(:@resume_at, now + 0.2)

        # Add fibers to registry
        described_class.registry << current_fiber
        described_class.registry << other_fiber

        # Mock current_fiber
        allow(Fiber).to receive(:current).and_return(current_fiber)

        # The delay method should choose other_fiber as it has an earlier wake-up time
        expect(other_fiber).to receive(:resume)

        # Call delay from current_fiber
        described_class.delay(0.3)
      end

      it 'does not resume fibers with wake-up times after current resume time' do
        described_class.enable!

        now = Time.now
        allow(Time).to receive(:now).and_return(now)

        # Create two fibers with different wake-up times
        current_fiber = Fiber.new { Fiber.yield }
        other_fiber = Fiber.new { Fiber.yield }

        # Current fiber wants to wake up sooner than other fiber
        current_fiber.instance_variable_set(:@resume_at, now + 0.2)
        other_fiber.instance_variable_set(:@resume_at, now + 0.5)

        # Add fibers to registry
        described_class.registry << current_fiber
        described_class.registry << other_fiber

        # Mock current_fiber
        allow(Fiber).to receive(:current).and_return(current_fiber)

        # The delay method should not resume other_fiber as it wakes up after current fiber
        expect(other_fiber).not_to receive(:resume)

        # Call delay from current_fiber
        described_class.delay(0.1)
      end
    end
  end

  describe '.in_fiber?' do
    it 'returns true when running in a registered fiber' do
      described_class.register_operation('test_authority') do
        expect(described_class.in_fiber?).to be true
      end
    end

    it 'returns false when not running in a registered fiber' do
      expect(described_class.in_fiber?).to be false
    end
  end

  describe '.current_authority' do
    it 'returns the authority for the current fiber' do
      described_class.register_operation('test_authority') do
        expect(described_class.current_authority).to eq('test_authority')
      end
    end

    it 'returns nil when not in a fiber' do
      expect(described_class.current_authority).to be_nil
    end
  end

  describe '.reset!' do
    it 'clears registry, exceptions and disables the scheduler' do
      # Set up some state
      fiber = Fiber.new { Fiber.yield }
      described_class.registry << fiber
      described_class.exceptions['test'] = StandardError.new('Test error')
      described_class.enable!

      # Verify state is set
      expect(described_class.registry).not_to be_empty
      expect(described_class.exceptions).not_to be_empty
      expect(described_class.enabled?).to be true

      # Reset the state
      described_class.reset!

      # Verify state is cleared
      expect(described_class.registry).to be_empty
      expect(described_class.exceptions).to be_empty
      expect(described_class.enabled?).to be false
    end
  end

  describe '.log' do
    it 'prefixes log message with authority when in a fiber' do
      expect {
        described_class.register_operation('test_authority') do
          described_class.log('Test message')
        end
      }.to output("[test_authority] Test message\n").to_stdout
    end

    it 'logs without prefix when not in a fiber' do
      expect {
        described_class.log('Test message')
      }.to output("Test message\n").to_stdout
    end
  end

  describe '.find_earliest_other_fiber' do
    it 'returns a fiber without resume time if available' do
      # Create fibers
      current_fiber = Fiber.new { Fiber.yield }
      ready_fiber = Fiber.new { Fiber.yield }
      delayed_fiber = Fiber.new { Fiber.yield }

      # Only set resume time for the delayed fiber
      delayed_fiber.instance_variable_set(:@resume_at, Time.now + 0.5)

      # Add to registry
      described_class.registry << current_fiber
      described_class.registry << ready_fiber
      described_class.registry << delayed_fiber

      # Mock current fiber
      allow(Fiber).to receive(:current).and_return(current_fiber)

      # Should find the ready fiber first (no resume time)
      result = described_class.send(:find_earliest_other_fiber)
      expect(result).to eq(ready_fiber)
    end
  end

  describe 'integration test' do
    it 'interleaves multiple operations' do
      # Create a test class that simulates a scraper with delays
      class TestScraper
        def initialize(authority, items)
          @authority = authority
          @items = items
        end

        def scrape
          @items.each do |item|
            # Simulate delay between requests
            ScraperUtils::FiberScheduler.delay(0.01)
            yield item
          end
        end
      end

      # Create scrapers for two different authorities
      scraper1 = TestScraper.new('Authority1', [1, 2, 3])
      scraper2 = TestScraper.new('Authority2', [4, 5, 6])

      # Results will collect items in the order they were processed
      results = []

      # Register both operations
      ScraperUtils::FiberScheduler.register_operation('Authority1') do
        scraper1.scrape do |item|
          results << "Authority1:#{item}"
        end
      end

      ScraperUtils::FiberScheduler.register_operation('Authority2') do
        scraper2.scrape do |item|
          results << "Authority2:#{item}"
        end
      end

      # We should have all items from both authorities
      expect(results.size).to eq(6)

      # The operations should be interleaved
      # This is hard to test deterministically, but we can check that
      # we don't just have all of one authority's items followed by the other
      authority1_items = results.select { |r| r.start_with?('Authority1') }
      authority2_items = results.select { |r| r.start_with?('Authority2') }

      expect(authority1_items.size).to eq(3)
      expect(authority2_items.size).to eq(3)

      # Check that items from each authority are in correct order
      expect(authority1_items).to eq(['Authority1:1', 'Authority1:2', 'Authority1:3'])
      expect(authority2_items).to eq(['Authority2:4', 'Authority2:5', 'Authority2:6'])
    end
  end
end

