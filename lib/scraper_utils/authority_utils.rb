# frozen_string_literal: true

module ScraperUtils
  # Utilities for managing and selecting authorities
  module AuthorityUtils
    AUTHORITIES_ENV_VAR = "MORPH_AUTHORITIES"

    # Selects authorities based on environment variable or returns all authorities
    #
    # @param all_authorities [Array<Symbol>] Full list of available authorities
    # @return [Array<Symbol>] Selected subset of authorities or all authorities
    # @raise [ScraperUtils::Error] If invalid authorities are specified in MORPH_AUTHORITIES
    def self.selected_authorities(all_authorities)
      if ENV[AUTHORITIES_ENV_VAR]
        authorities = ENV[AUTHORITIES_ENV_VAR].split(",").map(&:strip).map(&:to_sym)
        invalid = authorities - all_authorities
        unless invalid.empty?
          raise ScraperUtils::Error,
                "Invalid authorities specified in MORPH_AUTHORITIES: #{invalid.join(', ')}"
        end

        authorities
      else
        all_authorities
      end
    end
  end
end
