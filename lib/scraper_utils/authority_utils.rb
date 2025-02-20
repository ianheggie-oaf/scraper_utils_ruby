# frozen_string_literal: true

module ScraperUtils
  # Utilities for AUTHORITIES list
  module AuthorityUtils
    # Returns all_authorities or selected subset if ENV["MORPH_AUTHORITIES"] set
    # @param all_authorities
    def self.selected_authorities(all_authorities)
      if ENV["MORPH_AUTHORITIES"]
        authorities = ENV["MORPH_AUTHORITIES"].split(",").map(&:strip).map(&:to_sym)
        invalid = authorities - all_authorities
        unless invalid.empty?
          raise "Invalid authorities specified in MORPH_AUTHORITIES: #{invalid.join(', ')}"
        end

        authorities
      else
        all_authorities
      end
    end
  end
end
