# frozen_string_literal: true

require_relative "../spec_helper"
require "date"

RSpec.describe ScraperUtils::LogUtils do
  describe ".log_scraping_run" do
    let(:run_at) { Time.now - 123 }
    let(:authorities) { %i[good_council interrupted_council broken_council empty_council] }
    
    # Mock DataQualityMonitor stats
    before do
      allow(ScraperUtils::DataQualityMonitor).to receive(:stats).and_return({
        good_council: { saved: 10, unprocessed: 0 },
        interrupted_council: { saved: 5, unprocessed: 0 },
        broken_council: { saved: 0, unprocessed: 10 },
        empty_council: { saved: 0, unprocessed: 0 }
      })
    end

    let(:exceptions) do
      {
        interrupted_council: StandardError.new("Test error"),
        broken_council: StandardError.new("Test error")
      }
    end

    it "logs scraping run for multiple authorities" do
      expect(ScraperWiki).to receive(:save_sqlite)
        .with(%w[authority_label run_at],
              hash_including("authority_label" => "good_council",
                             "attempt" => 1,
                             "error_backtrace" => nil,
                             "error_class" => nil,
                             "error_message" => nil,
                             "records_scraped" => 10,
                             "run_at" => run_at.iso8601,
                             "status" => "successful",
                             "unprocessable_records" => 0,
                             "used_proxy" => 0),
              ScraperUtils::LogUtils::LOG_TABLE)
        .once
      expect(ScraperWiki).to receive(:save_sqlite)
        .with(%w[authority_label run_at],
              hash_including("authority_label" => "interrupted_council",
                             "attempt" => 1,
                             "error_backtrace" => nil,
                             "error_class" => "StandardError",
                             "error_message" => "Test error",
                             "records_scraped" => 5,
                             "run_at" => run_at.iso8601,
                             "status" => "interrupted",
                             "unprocessable_records" => 0,
                             "used_proxy" => 0),
              ScraperUtils::LogUtils::LOG_TABLE)
        .once
      expect(ScraperWiki).to receive(:save_sqlite)
        .with(%w[authority_label run_at],
              hash_including("authority_label" => "broken_council",
                             "attempt" => 1,
                             "error_backtrace" => nil,
                             "error_class" => "StandardError",
                             "error_message" => "Test error",
                             "records_scraped" => 0,
                             "run_at" => run_at.iso8601,
                             "status" => "failed",
                             "unprocessable_records" => 10,
                             "used_proxy" => 0),
              ScraperUtils::LogUtils::LOG_TABLE)
        .once
      expect(ScraperWiki).to receive(:save_sqlite)
        .with(%w[authority_label run_at],
              hash_including("authority_label" => "empty_council",
                             "attempt" => 1,
                             "error_backtrace" => nil,
                             "error_class" => nil,
                             "error_message" => nil,
                             "records_scraped" => 0,
                             "run_at" => run_at.iso8601,
                             "status" => "failed",
                             "unprocessable_records" => 0,
                             "used_proxy" => 0),
              ScraperUtils::LogUtils::LOG_TABLE)
        .once
      expect(ScraperWiki).to receive(:save_sqlite)
        .with(["run_at"],
              hash_including(
                "attempt" => 1,
                "duration" => 123.0,
                "failed" => "broken_council,empty_council",
                "failed_count" => 2,
                "interrupted" => "interrupted_council",
                "interrupted_count" => 1,
                "run_at" => run_at.iso8601,
                "successful" => "good_council",
                "successful_count" => 1
              ),
              ScraperUtils::LogUtils::SUMMARY_TABLE)
        .once

      described_class.log_scraping_run(run_at, 1, authorities, exceptions)
    end

    it "raises error for invalid start time" do
      deliberately_not_time = "not a time object"
      expect do
        # noinspection RubyMismatchedArgumentType
        described_class.log_scraping_run(deliberately_not_time, 1, authorities, results)
      end.to raise_error(ArgumentError, "Invalid start time")
    end

    it "raises error for empty authorities" do
      expect do
        described_class.log_scraping_run(run_at, 1, [], results)
      end.to raise_error(ArgumentError, "Authorities must be a non-empty array")
    end

    it "handles authorities with no results" do
      incomplete_results = { good_council: {} }

      %w[good_council interrupted_council broken_council empty_council].each do |authority_label|
        expect(ScraperWiki).to receive(:save_sqlite)
          .with(%w[authority_label run_at],
                hash_including("authority_label" => authority_label,
                               "attempt" => 1,
                               "error_backtrace" => nil,
                               "error_class" => nil,
                               "error_message" => nil,
                               "records_scraped" => 0,
                               "run_at" => run_at.iso8601,
                               "status" => "failed",
                               "unprocessable_records" => 0,
                               "used_proxy" => 0),
                ScraperUtils::LogUtils::LOG_TABLE)
          .once
      end
      expect(ScraperWiki)
        .to receive(:save_sqlite)
        .with(["run_at"],
              hash_including(
                "duration" => 123.0,
                "attempt" => 1,
                "failed" => "good_council,interrupted_council,broken_council,empty_council",
                "failed_count" => 4,
                "interrupted" => "",
                "interrupted_count" => 0,
                "run_at" => run_at.iso8601,
                "successful" => "",
                "successful_count" => 0
              ),
              ScraperUtils::LogUtils::SUMMARY_TABLE)
        .once

      described_class.log_scraping_run(run_at, 1, authorities, incomplete_results)
    end

    it "tracks summary of different authority statuses" do
      summary_record = nil

      # Capture the summary record when it's saved
      allow(ScraperWiki).to receive(:save_sqlite) do |_keys, record, table|
        summary_record = record if table == ScraperUtils::LogUtils::SUMMARY_TABLE
      end

      described_class.log_scraping_run(run_at, 1, authorities, results)

      expect(summary_record).not_to be_nil
      expect(summary_record["successful"]).to include("good_council")
      expect(summary_record["interrupted"]).to include("interrupted_council")
      expect(summary_record["failed"]).to include("broken_council,empty_council")
    end

    it "performs periodic record cleanup" do
      expect(described_class).to receive(:cleanup_old_records).exactly(1).times

      described_class.log_scraping_run(run_at, 1, authorities, results)
    end

    it "performs cleanup_old_records once per day" do
      [
        ScraperUtils::LogUtils::SUMMARY_TABLE,
        ScraperUtils::LogUtils::LOG_TABLE
      ].each do |table|
        expect(ScraperWiki)
          .to receive(:sqliteexecute)
          .with("DELETE FROM #{table} WHERE date(run_at) < date(?)", [be_a(String)])
          .exactly(1).times
      end
      described_class.cleanup_old_records(force: true)
      described_class.cleanup_old_records
    end

    context "with a complex backtrace" do
      let(:complex_error) do
        error = StandardError.new("Test error")
        error.set_backtrace(
          [
            # Ruby/gem internal lines (should be limited to 3)
            "/app/vendor/ruby-3.2.2/lib/ruby/3.2.0/net/http.rb:1271:in `initialize'",
            "/app/vendor/ruby-3.2.2/lib/ruby/3.2.0/net/http.rb:1272:in `open'",
            "/app/vendor/ruby-3.2.2/lib/ruby/3.2.0/net/http.rb:1273:in `start'",
            "/app/vendor/bundle/ruby/3.2.0/gems/n.../net/http/persistent.rb:711:in `start'",
            "/app/vendor/bundle/ruby/3.2.0/gems/n.../http/persistent.rb:641:in `connection_for'",
            "/app/vendor/bundle/ruby/3.2.0/gems/n.../net/http/persistent.rb:941:in `request'",
            "/app/vendor/bundle/ruby/3.2.0/gems/m.../mechanize/http/agent.rb:284:in `fetch'",

            # Application-specific lines
            "/app/lib/masterview_scraper/authority_scraper.rb:59:in `scrape_api_period'",
            "/app/lib/masterview_scraper/authority_scraper.rb:30:in `scrape_period'",
            "/app/lib/masterview_scraper/authority_scraper.rb:9:in `scrape'",
            "/app/lib/masterview_scraper/authority_scraper.rb:42:in `main'"
          ]
        )
        error
      end

      let(:results) do
        {
          complex_council: {
            records_scraped: 0,
            error: complex_error,
            proxy_used: true
          }
        }
      end

      it "removes Ruby and gem internal traces and limits total lines" do
        log_record = nil

        # Capture the log record when it's saved
        allow(ScraperWiki).to receive(:save_sqlite) do |_keys, record, table|
          log_record = record if table == ScraperUtils::LogUtils::LOG_TABLE
        end

        described_class.log_scraping_run(run_at, 1, [:complex_council], results)

        expect(log_record).not_to be_nil

        trace = log_record["error_backtrace"]
        trace_lines = trace.split("\n")

        # Check total number of lines is limited to 6
        expect(trace_lines.length).to be <= 6

        # Check application-specific lines are present
        expect(trace).to include("authority_scraper.rb:59:in `scrape_api_period'")
        expect(trace).to include("authority_scraper.rb:30:in `scrape_period'")
        expect(trace).to include("authority_scraper.rb:9:in `scrape'")
        expect(trace).to include("authority_scraper.rb:42:in `main'")

        # Verify that vendor/Ruby lines are limited
        vendor_lines = trace_lines.select { |line| line.include?("/vendor/") }
        expect(vendor_lines.length).to be <= 3
      end
    end
  end

  describe ".extract_meaningful_backtrace" do
    context "with a complex backtrace" do
      let(:error) do
        error = StandardError.new("Test error")
        error.set_backtrace(
          [
            "/app/vendor/ruby-3.2.2/lib/ruby/3.2.0/net/http.rb:1271:in `initialize'",
            "/app/vendor/ruby-3.2.2/lib/ruby/3.2.0/net/http.rb:1271:in `open'",
            "/app/vendor/bundle/ruby/3.2.0/gems/m.../lib/m.../http/agent.rb:284:in `fetch'",
            "/app/lib/masterview_scraper/authority_scraper.rb:59:in `scrape_api_period'",
            "/app/lib/masterview_scraper/authority_scraper.rb:30:in `scrape_period'",
            "/app/lib/masterview_scraper/authority_scraper.rb:9:in `scrape'",
            "/app/lib/masterview_scraper/authority_scraper.rb:42:in `main'"
          ]
        )
        error
      end

      it "removes Ruby and gem internal traces" do
        meaningful_trace = described_class.extract_meaningful_backtrace(error)

        expect(meaningful_trace).to include("authority_scraper.rb:59:in `scrape_api_period'")
        expect(meaningful_trace).to include("authority_scraper.rb:30:in `scrape_period'")
        expect(meaningful_trace).to include("authority_scraper.rb:9:in `scrape'")
        expect(meaningful_trace).to include("authority_scraper.rb:42:in `main'")
      end
    end

    context "with a nil error" do
      it "returns nil" do
        expect(described_class.extract_meaningful_backtrace(nil)).to be_nil
      end
    end

    context "with an error without backtrace" do
      it "returns nil" do
        error = StandardError.new("Test error")
        error.set_backtrace(nil)

        expect(described_class.extract_meaningful_backtrace(error)).to be_nil
      end
    end
  end

  describe ".report_on_results" do
    let(:authorities) { %i[good_council bad_council broken_council] }

    context "when all authorities work as expected" do
      let(:results) do
        {
          good_council: { records_scraped: 10, error: nil },
          bad_council: { records_scraped: 0, error: nil },
          broken_council: { records_scraped: 0, error: nil }
        }
      end

      it "exits with OK status when no unexpected conditions" do
        ENV["MORPH_EXPECT_BAD"] = "bad_council"

        expect { described_class.report_on_results(authorities, results) }
          .to output(/Exiting with OK status!/).to_stdout

        ENV["MORPH_EXPECT_BAD"] = nil
      end
    end

    context "when an expected bad authority starts working" do
      let(:exceptions) { {} }

      before do
        # Mock DataQualityMonitor stats for bad_council
        allow(ScraperUtils::DataQualityMonitor).to receive(:stats).and_return({
          bad_council: { saved: 5, unprocessed: 0 }
        })
      end

      it "raises an error with a warning about removing from EXPECT_BAD" do
        ENV["MORPH_EXPECT_BAD"] = "bad_council"

        expect { described_class.report_on_results([:good_council, :bad_council, :broken_council], exceptions) }
          .to raise_error(RuntimeError, /WARNING: Remove bad_council from MORPH_EXPECT_BAD/)

        ENV["MORPH_EXPECT_BAD"] = nil
      end
    end

    context "when an unexpected error occurs" do
      it "raises an error with details about unexpected errors" do
        ENV["MORPH_EXPECT_BAD"] = "bad_council"

        expect { described_class.report_on_results(authorities, exceptions) }
          .to raise_error(RuntimeError, /ERROR: Unexpected errors in: interrupted_council,broken_council/)
          .and output(/interrupted_council: StandardError - Test error/).to_stdout
          .and output(/broken_council: StandardError - Test error/).to_stdout

        ENV["MORPH_EXPECT_BAD"] = nil
      end
    end

    context "with no MORPH_EXPECT_BAD set" do
      let(:results) do
        {
          good_council: { records_scraped: 10, error: nil },
          bad_council: { records_scraped: 0, error: nil },
          broken_council: { records_scraped: 0, error: nil }
        }
      end

      it "works without any environment variable" do
        expect { described_class.report_on_results(authorities, results) }
          .to output(/Exiting with OK status!/).to_stdout
      end
    end
  end
end
