require 'spec_helper'

RSpec.describe ScraperUtils::AuthorityUtils do
  describe '.selected_authorities' do
    let(:all_authorities) { [:council1, :council2, :council3] }

    context 'when MORPH_AUTHORITIES is not set' do
      before { ENV.delete('MORPH_AUTHORITIES') }

      it 'returns all authorities' do
        expect(described_class.selected_authorities(all_authorities))
          .to match_array(all_authorities)
      end
    end

    context 'when MORPH_AUTHORITIES is set' do
      before { ENV['MORPH_AUTHORITIES'] = 'council1, council2' }
      after { ENV.delete('MORPH_AUTHORITIES') }

      it 'returns specified authorities' do
        expect(described_class.selected_authorities(all_authorities))
          .to match_array([:council1, :council2])
      end
    end

    context 'when MORPH_AUTHORITIES contains invalid authorities' do
      before { ENV['MORPH_AUTHORITIES'] = 'council1, invalid_council' }
      after { ENV.delete('MORPH_AUTHORITIES') }

      it 'raises an error' do
        expect {
          described_class.selected_authorities(all_authorities)
        }.to raise_error(
          ScraperUtils::Error, 
          /Invalid authorities specified in MORPH_AUTHORITIES: invalid_council/
        )
      end
    end

    context 'when MORPH_AUTHORITIES contains whitespace' do
      before { ENV['MORPH_AUTHORITIES'] = ' council1 , council2 ' }
      after { ENV.delete('MORPH_AUTHORITIES') }

      it 'handles whitespace correctly' do
        expect(described_class.selected_authorities(all_authorities))
          .to match_array([:council1, :council2])
      end
    end
  end
end
