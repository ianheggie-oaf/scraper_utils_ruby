# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScraperUtils do
  describe '.debug?' do
    context 'when DEBUG environment variable is set' do
      before { ENV[ScraperUtils::DEBUG_ENV_VAR] = 'true' }
      after { ENV.delete(ScraperUtils::DEBUG_ENV_VAR) }

      it 'returns true' do
        expect(described_class.debug?).to be true
      end
    end

    context 'when DEBUG environment variable is not set' do
      before { ENV.delete(ScraperUtils::DEBUG_ENV_VAR) }

      it 'returns false' do
        expect(described_class.debug?).to be false
      end
    end
  end

  describe '.australian_proxy' do
    context 'when AUSTRALIAN_PROXY environment variable is set' do
      before { ENV[ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR] = 'https://proxy.example.com' }
      after { ENV.delete(ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR) }

      it 'returns the proxy value' do
        expect(described_class.australian_proxy).to eq('https://proxy.example.com')
      end
    end

    context 'when AUSTRALIAN_PROXY environment variable is not set' do
      before { ENV.delete(ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR) }

      it 'returns nil' do
        expect(described_class.australian_proxy).to be_nil
      end
    end
  end
end
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScraperUtils do
  describe '.debug?' do
    context 'when DEBUG environment variable is set' do
      before { ENV[ScraperUtils::DEBUG_ENV_VAR] = 'true' }
      after { ENV.delete(ScraperUtils::DEBUG_ENV_VAR) }

      it 'returns true' do
        expect(described_class.debug?).to be true
      end
    end

    context 'when DEBUG environment variable is not set' do
      before { ENV.delete(ScraperUtils::DEBUG_ENV_VAR) }

      it 'returns false' do
        expect(described_class.debug?).to be false
      end
    end
  end

  describe '.australian_proxy' do
    context 'when AUSTRALIAN_PROXY environment variable is set' do
      before { ENV[ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR] = 'https://proxy.example.com' }
      after { ENV.delete(ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR) }

      it 'returns the proxy value' do
        expect(described_class.australian_proxy).to eq('https://proxy.example.com')
      end
    end

    context 'when AUSTRALIAN_PROXY environment variable is not set' do
      before { ENV.delete(ScraperUtils::AUSTRALIAN_PROXY_ENV_VAR) }

      it 'returns nil' do
        expect(described_class.australian_proxy).to be_nil
      end
    end
  end
end
