# frozen_string_literal: true

require "spec_helper"

RSpec.describe ScraperUtils::MechanizeUtils do
  describe ".mechanize_agent" do
    context "with delays" do
      before do
        stub_request(:get, "https://example.com/robots.txt")
          .to_return(status: 200, body: "")
        stub_request(:get, "https://example.com")
          .to_return(status: 200, body: "<html><body>Test page</body></html>")
      end

      it "applies random delay when specified" do
        start_time = Time.now
        agent = described_class.mechanize_agent(random_delay: 0.1)  # Small delay for testing
        agent.get("https://example.com")
        elapsed = Time.now - start_time
        
        expect(elapsed).to be >= 0.1
      end

      it "applies response-based delay when enabled" do
        allow_any_instance_of(AdaptiveDelay).to receive(:next_delay)
          .with(String, Numeric)  # Allow any domain and response time
          .and_return(0.1)  # Small delay for testing
        
        start_time = Time.now
        agent = described_class.mechanize_agent(response_delay: true)
        agent.get("https://example.com")
        elapsed = Time.now - start_time
        
        expect(elapsed).to be >= 0.1
      end

      it "combines multiple delay types" do
        stub_request(:get, "https://example.com/robots.txt")
          .to_return(status: 200, body: "User-agent: *\nCrawl-delay: 0.1\n")

        allow_any_instance_of(AdaptiveDelay).to receive(:next_delay)
          .with(String, Numeric)
          .and_return(0.1)

        start_time = Time.now
        agent = described_class.mechanize_agent(
          compliant_mode: true,
          response_delay: true,
          random_delay: 0.1
        )
        agent.get("https://example.com")
        elapsed = Time.now - start_time

        # Should combine all delays (0.1 + 0.1 + 0.1)
        expect(elapsed).to be >= 0.3
      end
    end
  end
end
