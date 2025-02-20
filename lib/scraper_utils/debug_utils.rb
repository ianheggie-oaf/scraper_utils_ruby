# frozen_string_literal: true

require "json"

module ScraperUtils
  # Utilities to assist in debugging scraper when ENV['DEBUG'] is set
  module DebugUtils
    def self.debug_request(method, url, parameters: nil, headers: nil, body: nil)
      return unless ENV["DEBUG"]

      puts "\n🔍 #{method.upcase} #{url}"
      if parameters
        puts "Parameters:"
        puts JSON.pretty_generate(parameters)
      end
      if headers
        puts "Headers:"
        puts JSON.pretty_generate(headers)
      end
      return unless body

      puts "Body:"
      puts JSON.pretty_generate(body)
    end

    def self.debug_page(page, message)
      return unless ENV["DEBUG"]

      puts "",
           "🔍 DEBUG: #{message}"
      puts "Current URL: #{page.uri}"
      puts "Page title: #{page.at('title').text.strip}" if page.at("title")
      puts "",
           "Page content:"
      puts "-" * 40
      puts page.body
      puts "-" * 40
    end

    def self.debug_selector(page, selector, message)
      return unless ENV["DEBUG"]

      puts "\n🔍 DEBUG: #{message}"
      puts "Looking for selector: #{selector}"
      element = page.at(selector)
      if element
        puts "Found element:"
        puts element.to_html
      else
        puts "Element not found in:"
        puts "-" * 40
        puts page.body
        puts "-" * 40
      end
    end
  end
end
