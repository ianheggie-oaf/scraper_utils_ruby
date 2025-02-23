# frozen_string_literal: true

require "spec_helper"
require "net/http"
require "uri"

RSpec.describe RobotsChecker do
  let(:user_agent) { "Mozilla/5.0 (compatible; ScraperUtils/1.0.0 2025-02-23; +https://github.com/example/scraper)" }
  subject(:robots_checker) { described_class.new(user_agent) }

  describe "#initialize" do
    it "extracts the correct user agent prefix" do
      expect(robots_checker.instance_variable_get(:@user_agent)).to eq("scraperutils/1.0.0")
    end

    context "with different user agent formats" do
      it "handles user agent without 'compatible' prefix" do
        checker = described_class.new("ScraperUtils/1.2.3")
        expect(checker.instance_variable_get(:@user_agent)).to eq("scraperutils/1.2.3")
      end
    end
  end

  describe "#allowed?" do
    let(:mock_http) { class_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:get_response) do |uri|
        case uri.to_s
        when "https://example.com/robots.txt"
          response = instance_double(Net::HTTPResponse)
          allow(response).to receive(:code).and_return("200")
          allow(response).to receive(:body).and_return(robots_txt_content)
          response
        else
          raise SocketError
        end
      end
    end

    context "with robots.txt matching our user agent" do
      let(:robots_txt_content) do
        <<~ROBOTS
          User-agent: ScraperUtils
          Disallow: /private/
          Crawl-delay: 10
        ROBOTS
      end

      it "allows access to allowed paths" do
        expect(robots_checker.allowed?("https://example.com/public/page")).to be true
      end

      it "blocks access to disallowed paths for specific user agent" do
        expect(robots_checker.allowed?("https://example.com/private/secret")).to be false
      end

      it "returns crawl delay for specific user agent" do
        robots_checker.allowed?("https://example.com/")
        expect(robots_checker.crawl_delay).to eq(10)
      end
    end

    context "when robots.txt is unavailable" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(SocketError)
      end

      it "allows access by default" do
        expect(robots_checker.allowed?("https://example.org/any/path")).to be true
      end

      it "returns nil crawl delay" do
        robots_checker.allowed?("https://example.org/")
        expect(robots_checker.crawl_delay).to be_nil
      end
    end

    context "with multiple user agent rules" do
      let(:robots_txt_content) do
        <<~ROBOTS
          User-agent: ScraperUtils/1.0.0
          Disallow: /specific/
          Crawl-delay: 15

          User-agent: ScraperUtils
          Disallow: /general/
          Crawl-delay: 10
        ROBOTS
      end

      it "prioritizes most specific user agent rules" do
        expect(robots_checker.allowed?("https://example.biz/specific/page")).to be false
        expect(robots_checker.crawl_delay).to eq(15)
      end
    end
  end

  describe "#parse_robots_txt" do
    subject(:parse_method) { robots_checker.method(:parse_robots_txt) }

    it "handles empty robots.txt" do
      result = parse_method.call("")
      expect(result).to eq(our_rules: [], our_delay: nil)
    end

    it "handles case-insensitive parsing" do
      content = <<~ROBOTS
        User-Agent: ScraperUtils
        Disallow: /PRIVATE/
        Crawl-Delay: 10
      ROBOTS

      result = parse_method.call(content)
      expect(result[:our_rules]).to eq(["/private/"])
      expect(result[:our_delay]).to eq(10)
    end
  end
end
