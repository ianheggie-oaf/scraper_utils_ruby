# frozen_string_literal: true

require_relative "../spec_helper"
require "net/http"
require "uri"

RSpec.describe RobotsChecker do
  let(:user_agent) { "Mozilla/5.0 (compatible; ScraperUtils/1.0.0 2025-02-23; +https://github.com/example/scraper)" }
  subject(:robots_checker) { described_class.new(user_agent) }

  describe "#initialize" do
    it "extracts the correct user agent prefix" do
      expect(robots_checker.instance_variable_get(:@user_agent)).to eq("scraperutils")
    end

    context "with different user agent formats" do
      it "handles user agent without 'compatible' prefix" do
        checker = described_class.new("ScraperUtils/1.2.3")
        expect(checker.instance_variable_get(:@user_agent)).to eq("scraperutils")
      end
    end

    it "logs user agent when debugging" do
      ENV["DEBUG"] = "1"
      expect {
        described_class.new(user_agent)
      }.to output(/Checking robots.txt for user agent prefix: scraperutils/).to_stdout
      ENV["DEBUG"] = nil
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

    context "with empty URL" do
      it "returns true for nil URL" do
        expect(robots_checker.allowed?(nil)).to be true
      end

      it "returns true for empty string URL" do
        expect(robots_checker.allowed?("")).to be true
      end
    end

    context "with robots.txt fetch errors" do
      it "logs error in debug mode" do
        ENV["DEBUG"] = "1"
        expect {
          robots_checker.allowed?("https://error.com/test")
        }.to output(/Warning: Failed to fetch robots.txt/).to_stdout
        ENV["DEBUG"] = nil
      end
    end

    # ... rest of existing tests ...
  end
end
