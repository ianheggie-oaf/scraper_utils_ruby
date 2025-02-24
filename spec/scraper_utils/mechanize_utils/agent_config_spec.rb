# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe ScraperUtils::MechanizeUtils::AgentConfig do
  let(:proxy_url) { "https://user:password@test.proxy:8888" }

  before do
    stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
      .to_return(body: "1.2.3.4\n")
    ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
  end

  after do
    ENV["MORPH_AUSTRALIAN_PROXY"] = nil
  end

  describe "#initialize" do
    context "with no options" do
      it "creates default configuration and displays it" do
        expect { described_class.new }.to output(
          "Created Mechanize agent with \n"
        ).to_stdout
      end
    end

    context "with all options enabled" do
      it "creates configuration with all options and displays them" do
        expect {
          described_class.new(
            use_proxy: true,
            australian_proxy: true,
            timeout: 30,
            compliant_mode: true,
            random_delay: 5,
            response_delay: true,
            disable_ssl_certificate_check: true
          )
        }.to output(/Created Mechanize agent with .*timeout=30.*use_proxy.*compliant_mode.*random_delay=5.*response_delay.*disable_ssl_certificate_check/m).to_stdout
      end
    end
  end

  describe "#configure_agent" do
    let(:agent) { Mechanize.new }

    it "configures SSL verification when requested" do
      config = described_class.new(disable_ssl_certificate_check: true)
      config.configure_agent(agent)
      expect(agent.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it "configures proxy when available and requested" do
      config = described_class.new(use_proxy: true, australian_proxy: true)
      config.configure_agent(agent)
      expect(agent.agent.proxy_uri.to_s).to eq(proxy_url)
    end

    it "configures timeouts when specified" do
      config = described_class.new(timeout: 30)
      config.configure_agent(agent)
      expect(agent.open_timeout).to eq(30)
      expect(agent.read_timeout).to eq(30)
    end

    it "sets up pre and post connect hooks" do
      config = described_class.new
      config.configure_agent(agent)
      expect(agent.pre_connect_hooks.size).to eq(1)
      expect(agent.post_connect_hooks.size).to eq(1)
    end
  end
end
