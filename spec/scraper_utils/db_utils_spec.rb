# frozen_string_literal: true

require 'spec_helper'
require 'date'

RSpec.describe ScraperUtils::DbUtils do
  describe '.save_record' do
    let(:valid_record) do
      {
        'council_reference' => 'DA123',
        'address' => '123 Test St, Testville',
        'description' => 'Test development',
        'info_url' => 'https://example.com',
        'date_scraped' => Date.today.to_s
      }
    end

    it 'saves a valid record' do
      expect(ScraperWiki).to receive(:save_sqlite).with(['council_reference'], valid_record)
      described_class.save_record(valid_record)
    end

    context 'with optional date fields' do
      it 'validates date_received' do
        record = valid_record.merge('date_received' => Date.today.to_s)
        expect(ScraperWiki).to receive(:save_sqlite).with(['council_reference'], record)
        described_class.save_record(record)
      end

      it 'validates on_notice_from' do
        record = valid_record.merge('on_notice_from' => Date.today.to_s)
        expect(ScraperWiki).to receive(:save_sqlite).with(['council_reference'], record)
        described_class.save_record(record)
      end

      it 'validates on_notice_to' do
        record = valid_record.merge('on_notice_to' => Date.today.to_s)
        expect(ScraperWiki).to receive(:save_sqlite).with(['council_reference'], record)
        described_class.save_record(record)
      end
    end

    context 'with missing required fields' do
      it 'raises an error for missing council_reference' do
        record = valid_record.merge('council_reference' => '')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /council_reference/)
      end

      it 'raises an error for missing address' do
        record = valid_record.merge('address' => '')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /address/)
      end

      it 'raises an error for missing description' do
        record = valid_record.merge('description' => '')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /description/)
      end

      it 'raises an error for missing info_url' do
        record = valid_record.merge('info_url' => '')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /info_url/)
      end

      it 'raises an error for missing date_scraped' do
        record = valid_record.merge('date_scraped' => '')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /date_scraped/)
      end
    end

    context 'with invalid date formats' do
      it 'raises an error for invalid date_scraped' do
        record = valid_record.merge('date_scraped' => 'invalid-date')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /Invalid date format/)
      end

      it 'raises an error for invalid date_received' do
        record = valid_record.merge('date_received' => 'invalid-date')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /Invalid date format/)
      end

      it 'raises an error for invalid on_notice_from' do
        record = valid_record.merge('on_notice_from' => 'invalid-date')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /Invalid date format/)
      end

      it 'raises an error for invalid on_notice_to' do
        record = valid_record.merge('on_notice_to' => 'invalid-date')
        expect {
          described_class.save_record(record)
        }.to raise_error(ScraperUtils::UnprocessableRecord, /Invalid date format/)
      end
    end

    context 'with authority_label' do
      it 'uses authority_label in primary key' do
        record = valid_record.merge('authority_label' => 'test_council')
        expect(ScraperWiki).to receive(:save_sqlite).with(['authority_label', 'council_reference'], record)
        described_class.save_record(record)
      end
    end
  end
end
