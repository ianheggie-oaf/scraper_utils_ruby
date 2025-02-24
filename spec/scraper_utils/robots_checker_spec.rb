# frozen_string_literal: true

require_relative "../spec_helper"
require "net/http"
require "uri"

RSpec.describe RobotsChecker do
  let(:user_agent) { "Mozilla/5.0 (compatible; ScraperUtils/1.0.0 2025-02-23; +https://github.com/example/scraper)" }
  subject(:robots_checker) { described_class.new(user_agent) }

  after do
    ENV["DEBUG"] = nil
  end

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
    context "with debug logging" do
      before { ENV["DEBUG"] = "1" }

      it "logs robots.txt fetch errors" do
        stub_request(:get, "https://example.com/robots.txt")
          .to_raise(StandardError.new("test error"))

        expect {
          robots_checker.allowed?("https://example.com/test")
        }.to output(/Warning: Failed to fetch robots.txt.*test error/m).to_stdout
      end
    end

    context "when checking simple URLs" do
      it "returns true for empty URL" do
        expect(robots_checker.allowed?("")).to be true
      end

      it "returns true for missing URL" do
        expect(robots_checker.allowed?(nil)).to be true
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
  end
end
