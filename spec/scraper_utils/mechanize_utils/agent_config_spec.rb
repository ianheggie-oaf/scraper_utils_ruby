# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe ScraperUtils::MechanizeUtils do
  describe ".mechanize_agent" do
    let(:proxy_url) { "https://user:password@test.proxy:8888" }

    before do
      #allow(ScraperUtils).to receive(:australian_proxy).and_return(proxy_url)
      stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
        .to_return(body: "1.2.3.4\n")
      ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
    end

    after do
      ENV["MORPH_AUSTRALIAN_PROXY"] = nil
    end

    it "creates an agent with SSL verification enabled" do
      agent = described_class.mechanize_agent(use_proxy: false, timeout: nil)
      expect(agent.verify_mode).not_to eq(OpenSSL::SSL::VERIFY_NONE)
    end


    it "creates an agent with SSL verification disabled when requested" do
      agent = described_class.mechanize_agent(disable_ssl_certificate_check: true)
      expect(agent.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    context "with proxy" do
      it "sets proxy when use_proxy is true and proxy is available" do
        agent = described_class.mechanize_agent(use_proxy: true, australian_proxy: true, timeout: nil)
        expect(agent.agent.proxy_uri.to_s).to eq(proxy_url)
      end

      it "does not set proxy when proxy is empty" do
        allow(ScraperUtils).to receive(:australian_proxy).and_return("")
        agent = described_class.mechanize_agent(use_proxy: true, australian_proxy: true, timeout: nil)
        expect(agent.agent.proxy_uri).to be_nil
      end

      it "does not set proxy when authority doesn't need it" do
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
end
