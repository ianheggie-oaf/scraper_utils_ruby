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
          "Created Mechanize agent with australian_proxy=false.\n"
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

    context "with proxy configuration edge cases" do
      it "handles proxy without australian_proxy authority" do
        expect {
          described_class.new(use_proxy: true)
        }.to output(/australian_proxy=false/).to_stdout
      end

      it "handles empty proxy URL" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = nil
        expect {
          described_class.new(use_proxy: true, australian_proxy: true)
        }.to output(/#{ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR} not set/).to_stdout
      end
    end
  end

  describe "#configure_agent" do
    let(:agent) { Mechanize.new }

    context "with proxy verification" do
      it "handles invalid IP formats" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
        stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
          .to_return(body: "invalid.ip.address\n")

        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(/Invalid public IP address returned by proxy check/)
      end
    end

    context "with post_connect_hook" do
      it "requires a URI" do
        config = described_class.new
        config.configure_agent(agent)
        hook = agent.post_connect_hooks.first

        expect {
          hook.call(agent, nil, double("response"), "body")
        }.to raise_error(ArgumentError, "URI must be present in post-connect hook")
      end
    end
  end
end
