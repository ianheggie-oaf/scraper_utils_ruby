# frozen_string_literal: true

require 'scraper_wiki'

module ScraperUtils
  # Database Utilities
  module DbUtils
    # Save record to database with logging
    def self.save_record(record)
      puts "Saving record #{record['council_reference']} - #{record['address']}"
      ScraperWiki.save_sqlite(%w[authority_label council_reference], record)
    end
  end
end
