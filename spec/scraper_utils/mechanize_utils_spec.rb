# frozen_string_literal: true

require "spec_helper"
require "mechanize"
require "nokogiri"
require "webmock/rspec"
require "openssl"
require "rspec/mocks"

RSpec.describe ScraperUtils::MechanizeUtils do
  describe ".mechanize_agent" do
    let(:proxy_url) { "https://user:password@test.proxy:8888" }

    before do
      allow(ScraperUtils).to receive(:australian_proxy).and_return(proxy_url)
      stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
        .to_return(body: "1.2.3.4\n")
      ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
    end

    after do
      ENV["MORPH_AUSTRALIAN_PROXY"] = nil
    end

    it "creates an agent with SSL verification disabled" do
      agent = described_class.mechanize_agent(use_proxy: false, timeout: nil)
      expect(agent.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    context "with proxy" do
      it "sets proxy when use_proxy is true and proxy is available" do
        agent = described_class.mechanize_agent(use_proxy: true, timeout: nil)
        expect(agent.agent.proxy_uri.to_s).to eq(proxy_url)
      end

      it "does not set proxy when proxy is empty" do
        allow(ScraperUtils).to receive(:australian_proxy).and_return("")
        agent = described_class.mechanize_agent(use_proxy: true, timeout: nil)
        expect(agent.agent.proxy_uri).to be_nil
      end
    end

    context "without proxy" do
      it "does not set proxy" do
        agent = described_class.mechanize_agent(use_proxy: false, timeout: nil)
        expect(agent.agent.proxy_uri).to be_nil
      end
    end

    context "with timeout" do
      it "sets open and read timeouts" do
        agent = described_class.mechanize_agent(use_proxy: false, timeout: 30)
        expect(agent.open_timeout).to eq(30)
        expect(agent.read_timeout).to eq(30)
      end
    end
  end

  describe ".find_maintenance_message" do
    context "with maintenance text" do
      before do
        stub_request(:get, "https://example.com/")
          .to_return(
            status: 200,
            body: "<html><h1>System Under Maintenance</h1></html>"
          )
      end

      it "detects maintenance in h1" do
        agent = Mechanize.new
        page = agent.get("https://example.com/")

        expect(described_class.find_maintenance_message(page))
          .to eq("Maintenance: System Under Maintenance")
      end
    end

    context "without maintenance text" do
      before do
        stub_request(:get, "https://example.com/")
          .to_return(
            status: 200,
            body: "<html><h1>Normal Page</h1></html>"
          )
      end

      it "returns nil" do
        agent = Mechanize.new
        page = agent.get("https://example.com/")

        expect(described_class.find_maintenance_message(page)).to be_nil
      end
    end
  end

  describe ".public_ip" do
    before do
      stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
        .to_return(body: "1.2.3.4\n")
    end

    it "retrieves and logs public IP" do
      agent = Mechanize.new

      expect { described_class.public_ip(agent, force: true) }
        .to output(/Public IP: 1.2.3.4/).to_stdout
    end

    it "caches the IP address" do
      agent = Mechanize.new

      # First call should make the request
      first_ip = described_class.public_ip(agent, force: true)
      expect(first_ip).to eq("1.2.3.4")

      # Second call should return cached IP without making request
      second_ip = described_class.public_ip(agent)
      expect(second_ip).to eq("1.2.3.4")

      # Verify only one request was made
      expect(WebMock).to have_requested(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL).once
    end
  end

  describe ".using_proxy?" do
    let(:agent) { Mechanize.new }

    context "when proxy is set" do
      before do
        agent.agent.set_proxy("http://test.proxy:8888")
      end

      it "returns true" do
        expect(described_class.using_proxy?(agent)).to be true
      end
    end

    context "when no proxy is set" do
      it "returns false" do
        expect(described_class.using_proxy?(agent)).to be false
      end
    end
  end

  describe ".mechanize_agent" do
    # Existing tests...

    context "with pre-request hook" do
      let(:robots_checker) { instance_double(RobotsChecker) }
      let(:adaptive_delay) { instance_double(AdaptiveDelay) }

      before do
        allow(RobotsChecker).to receive(:new).and_return(robots_checker)
        allow(AdaptiveDelay).to receive(:new).and_return(adaptive_delay)
        allow(robots_checker).to receive(:allowed?).and_return(true)
        allow(robots_checker).to receive(:crawl_delay).and_return(0)
        allow(adaptive_delay).to receive(:next_delay).and_return(0.0)
      end

      it "checks robots.txt before making a request" do
        expect(robots_checker).to receive(:allowed?).with("https://example.com").and_return(true)
        
        agent = described_class.mechanize_agent(compliant_mode: true)
        stub_request(:get, "https://example.com")
        agent.get("https://example.com")
      end

      it "raises UnprocessableSite when URL is not allowed" do
        allow(robots_checker).to receive(:allowed?).and_return(false)

        agent = described_class.mechanize_agent(compliant_mode: true)
        expect {
          agent.get("https://example.com")
        }.to raise_error(ScraperUtils::UnprocessableSite)
      end

      it "applies random delay when specified" do
        agent = described_class.mechanize_agent(random_delay: 5)
        
        # We'll mock the rand method to return a predictable value
        allow(agent).to receive(:rand).and_return(0.5)
        
        stub_request(:get, "https://example.com")
        expect(agent).to receive(:sleep).with(be_between(0, 5))
        
        agent.get("https://example.com")
      end

      it "applies response-based delay when enabled" do
        expect(adaptive_delay).to receive(:next_delay).and_return(2.0)

        agent = described_class.mechanize_agent(response_delay: true)
        stub_request(:get, "https://example.com")
        expect(agent).to receive(:sleep).with(2.0)
        
        agent.get("https://example.com")
      end
    end
  end
end
