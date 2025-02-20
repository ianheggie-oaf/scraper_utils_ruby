# frozen_string_literal: true

require "scraper_utils/version"

module ScraperUtils
  # Fatal error with the site - retrying won't help
  class UnprocessableSite < StandardError
  end

  # Content validation errors that should not be retried for that record,
  # but other records may be processable
  class UnprocessableRecord < StandardError
  end


  # Your code goes here...
end
