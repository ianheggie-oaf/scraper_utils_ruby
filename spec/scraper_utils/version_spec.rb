# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScraperUtils::VERSION do
  it 'has a version number' do
    expect(ScraperUtils::VERSION).to be_a(String)
    expect(ScraperUtils::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it 'follows semantic versioning' do
    version_parts = ScraperUtils::VERSION.split('.')
    expect(version_parts.size).to be >= 3
    expect(version_parts[0].to_i).to be >= 0
    expect(version_parts[1].to_i).to be >= 0
    expect(version_parts[2].to_i).to be >= 0
  end

  it 'matches the version in the gemspec' do
    gemspec_path = File.expand_path('../../scraper_utils_ruby.gemspec', __dir__)
    gemspec_content = File.read(gemspec_path)
    expect(gemspec_content).to include("spec.version = ScraperUtils::VERSION")
  end

  it 'is a string constant' do
    expect(ScraperUtils::VERSION).to be_frozen
  end

  it 'is defined in the ScraperUtils module' do
    expect(defined?(ScraperUtils::VERSION)).to eq('constant')
  end
end
