# frozen_string_literal: true

require "scraper_wiki"

module ScraperUtils
  # Logging Utilities
  module LogUtils
    def self.log_scrape_attempt(authority, records_count, used_proxy, seconds, error_message)
      record = {
        "run_at" => Time.now.iso8601,
        "authority" => authority.to_s,
        "records_scraped" => records_count,
        "used_proxy" => used_proxy ? 1 : 0,
        "seconds" => seconds,
        "error_message" => error_message
      }
      ScraperWiki.save_sqlite(%w[authority run_at], record, "scrape_log")
      # Delete old records first (SQLite doesn't have direct datetime comparison)
      cutoff = (Date.today - 30).to_s
      return if @last_cutoff == cutoff

      @last_cutoff = cutoff
      ScraperWiki.sqliteexecute(
        "DELETE FROM scrape_log WHERE date(run_at) < date(?)",
        [cutoff]
      )
    end
  end
end
