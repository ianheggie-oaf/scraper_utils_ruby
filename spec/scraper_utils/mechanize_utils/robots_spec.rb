# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe ScraperUtils::MechanizeUtils do
  describe ".mechanize_agent" do
    let(:page_content) { "<html><body>Test page</body></html>" }

    before do
      stub_request(:get, "https://example.com")
        .to_return(status: 200, body: page_content)
    end

    context "with crawl delays" do
      context "when robots.txt has only default crawl delay" do
        before do
          stub_request(:get, "https://example.com/robots.txt")
            .to_return(status: 200, body: <<~ROBOTS
              User-agent: *
              Crawl-delay: 1
              Disallow: /admin

              User-agent: GPTBot
              Disallow: /
            ROBOTS
            )
        end

        it "uses the default crawl delay in compliant mode" do
          stub_request(:get, "https://example.com/admin")
            .to_return(status: 200, body: page_content)
          agent = described_class.mechanize_agent(compliant_mode: true)
          start_time = Time.now
          agent.get("https://example.com/admin")  # Should work despite default Disallow
          elapsed = Time.now - start_time
          expect(elapsed).to be >= 0.2  # Should use default crawl delay
        end
      end

      context "when robots.txt has a ScraperUtils section" do
        before do
          stub_request(:get, "https://example.com/robots.txt")
            .to_return(status: 200, body: <<~ROBOTS
              User-agent: *
              Crawl-delay: 2.2
              Disallow: /admin

              User-agent: ScraperUtils
              Allow: /
              Crawl-delay: 0.1
            ROBOTS
            )
        end

        it "uses the ScraperUtils crawl delay in compliant mode" do
          agent = described_class.mechanize_agent(compliant_mode: true)
          start_time = Time.now
          agent.get("https://example.com")
          elapsed = Time.now - start_time
          expect(elapsed).to be >= 0.1  # Should use ScraperUtils delay
          expect(elapsed).to be < 0.2   # Should NOT use default delay
        end
      end

      context "when ScraperUtils section has no crawl delay" do
        before do
          stub_request(:get, "https://example.com/robots.txt")
            .to_return(status: 200, body: <<~ROBOTS
              User-agent: *
              Crawl-delay: 2.2
              Disallow: /admin

              User-agent: ScraperUtils
              Allow: /
            ROBOTS
            )
        end

        it "ignores the default crawl delay when ScraperUtils section exists" do
          agent = described_class.mechanize_agent(compliant_mode: true)
          start_time = Time.now
          agent.get("https://example.com")
          elapsed = Time.now - start_time
          expect(elapsed).to be < 0.1  # Should NOT use any delay
        end
      end
    end

    context "with access rules" do
      context "when robots.txt explicitly blocks ScraperUtils" do
        before do
          stub_request(:get, "https://example.com/robots.txt")
            .to_return(status: 200, body: <<~ROBOTS
              User-agent: *
              Allow: /
              
              User-agent: ScraperUtils
              Disallow: /
            ROBOTS
            )
        end

        it "respects explicit ScraperUtils block in compliant mode" do
          agent = described_class.mechanize_agent(compliant_mode: true)
          expect { agent.get("https://example.com") }
            .to raise_error(ScraperUtils::UnprocessableSite)
        end

        it "ignores rules when compliant mode is off" do
          agent = described_class.mechanize_agent(compliant_mode: false)
          expect { agent.get("https://example.com") }.not_to raise_error
        end
      end
    end
  end
end
