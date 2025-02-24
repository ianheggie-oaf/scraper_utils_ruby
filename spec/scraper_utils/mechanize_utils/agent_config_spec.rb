# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe ScraperUtils::MechanizeUtils::AgentConfig do
  let(:proxy_url) { "https://user:password@test.proxy:8888" }

  before do
    stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
      .to_return(body: "1.2.3.4\n")
    # force use of new public_ip
    ScraperUtils::MechanizeUtils.public_ip(nil, force: true)
    ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
  end

  after do
    ENV["MORPH_AUSTRALIAN_PROXY"] = nil
    ENV["DEBUG"] = nil
  end

  describe "#initialize" do
    context "with no options" do
      it "creates default configuration and displays it" do
        expect { described_class.new }.to output(
          "Created Mechanize agent with australian_proxy=false.\n"
        ).to_stdout
      end
    end

    context "with debug logging" do
      before { ENV["DEBUG"] = "1" }

      it "logs connection details" do
        config = described_class.new
        config.configure_agent(Mechanize.new)
        expect {
          config.send(:pre_connect_hook, nil, double(inspect: "test request"))
        }.to output(/Pre Connect request: test request/).to_stdout
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
        }.to output(/Created Mechanize agent with australian_proxy=false/).to_stdout
      end

      it "handles empty proxy URL" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = ""
        expect {
          described_class.new(use_proxy: true, australian_proxy: true)
        }.to output(/Created Mechanize agent with MORPH_AUSTRALIAN_PROXY not set/).to_stdout
      end
    end

    context "with debug logging" do
      before { ENV["DEBUG"] = "1" }

      it "logs connection details" do
        config = described_class.new
        config.configure_agent(Mechanize.new)
        expect {
          config.send(:pre_connect_hook, nil, double(inspect: "test request"))
        }.to output(/Pre Connect request: test request/).to_stdout
      end
    end

    context "with post_connect_hook" do
      before { ENV["DEBUG"] = "1" }

      it "logs connection details" do
        config = described_class.new
        uri = URI("https://example.com")
        response = double(inspect: "test response")
        # required for post_connect_hook
        config.send(:pre_connect_hook, nil, nil)
        expect {
          config.send(:post_connect_hook, nil, uri, response, nil)
        }.to output(/Post Connect uri:.*response: test response/m).to_stdout
      end

      it "logs delay details when delay applied" do
        config = described_class.new(random_delay: 1)
        uri = URI("https://example.com")
        response = double(inspect: "test response")
        # required for post_connect_hook
        config.send(:pre_connect_hook, nil, nil)
        expect {
          config.send(:post_connect_hook, nil, uri, response, nil)
        }.to output(/Delaying \d+\.\d+ seconds/).to_stdout
      end
    end
  end

  describe "#configure_agent" do
    let(:agent) { Mechanize.new }

    context "with timeout configuration" do
      it "sets both read and open timeouts when specified" do
        config = described_class.new(timeout: 42)
        config.configure_agent(agent)
        expect(agent.open_timeout).to eq(42)
        expect(agent.read_timeout).to eq(42)
      end

      it "does not set timeouts when not specified" do
        original_open = agent.open_timeout
        original_read = agent.read_timeout
        config = described_class.new
        config.configure_agent(agent)
        expect(agent.open_timeout).to eq(original_open)
        expect(agent.read_timeout).to eq(original_read)
      end
    end

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

    it "sets up pre and post connect hooks" do
      config = described_class.new
      config.configure_agent(agent)
      expect(agent.pre_connect_hooks.size).to eq(1)
      expect(agent.post_connect_hooks.size).to eq(1)
    end

    context "with proxy verification" do
      it "handles invalid IP formats" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
        stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
          .to_return(body: "invalid.ip.address\n")
        # force use of new public_ip
        ScraperUtils::MechanizeUtils.public_ip(nil, force: true)
        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(/Invalid public IP address returned by proxy check/)
      end

      it "handles proxy connection timeout" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
        stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
          .to_timeout
        # force use of new public_ip
        ScraperUtils::MechanizeUtils.public_ip(nil, force: true)

        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(/Proxy check timed out/)
      end

      it "handles proxy connection refused" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
        stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
          .to_raise(Errno::ECONNREFUSED)
        # force use of new public_ip
        ScraperUtils::MechanizeUtils.public_ip(nil, force: true)

        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(/Failed to connect to proxy/)
      end

      it "handles proxy authentication failure" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = proxy_url
        stub_request(:get, ScraperUtils::MechanizeUtils::PUBLIC_IP_URL)
          .to_return(status: [407, "Proxy Authentication Required"])
        # force use of new public_ip
        ScraperUtils::MechanizeUtils.public_ip(nil, force: true)

        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(/Proxy authentication failed/)
      end

      it "handles malformed proxy URL" do
        ENV["MORPH_AUSTRALIAN_PROXY"] = "not-a-valid-url"
        # force use of new public_ip
        ScraperUtils::MechanizeUtils.public_ip(nil, force: true)

        config = described_class.new(use_proxy: true, australian_proxy: true)
        expect {
          config.configure_agent(agent)
        }.to raise_error(URI::InvalidURIError)
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
