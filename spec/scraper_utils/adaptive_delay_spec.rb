# frozen_string_literal: true

require "spec_helper"

RSpec.describe AdaptiveDelay do
  describe "#initialize" do
    it "sets initial delay to a float" do
      delay = described_class.new(initial_delay: 0.5)
      expect(delay.instance_variable_get(:@initial)).to be_a(Float)
      expect(delay.instance_variable_get(:@initial)).to eq(0.5)
    end

    it "uses default timeout when not provided" do
      delay = described_class.new
      expect(delay.instance_variable_get(:@max_delay)).to eq(15.0)
    end

    it "calculates max_delay as half of provided timeout" do
      delay = described_class.new(timeout: 60)
      expect(delay.instance_variable_get(:@max_delay)).to eq(30.0)
    end
  end

  describe "#next_delay" do
    let(:delay) { described_class.new(initial_delay: 1.0, timeout: 30) }

    it "starts with initial delay for a new domain" do
      expect(delay.next_delay("example.com", 2.0)).to eq(1.0)
    end

    it "adjusts delay based on response time" do
      first_delay = delay.next_delay("example.com", 2.0)
      second_delay = delay.next_delay("example.com", 3.0)
      expect(second_delay).to be_between(1.0, 2.0)
    end

    it "clamps delay between initial and max values" do
      delay = described_class.new(initial_delay: 1.0, timeout: 10)
      result = delay.next_delay("example.com", 20.0)
      expect(result).to be_between(1.0, 5.0)
    end

    context "with debug environment" do
      before { ENV["DEBUG"] = "true" }
      after { ENV.delete("DEBUG") }

      it "prints delay change when in debug mode" do
        expect { delay.next_delay("example.com", 2.0) }
          .to output(/Adaptive delay for example.com/).to_stdout
      end
    end
  end
end
