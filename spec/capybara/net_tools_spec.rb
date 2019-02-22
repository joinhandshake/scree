require 'spec_helper'

describe Capybara::Selenium::Driver::ChromeDriver do
  # This does not work right with CDP; find another way.
  describe '#blocked_urls=' do
    xit 'blocks specified urls'
  end

  # This does not work right with CDP; find another way.
  describe '#extra_http_headers=' do
    xit 'sends extra http headers'
  end

  describe '#user_agent' do
    it 'returns the current user_agent' do
      visit '/'

      expect(page.driver.user_agent).to include('HeadlessChrome')
    end
  end

  describe '#user_agent=' do
    it 'sets the current user_agent' do
      visit '/'

      page.driver.user_agent = 'TestBrowser'
      refresh
      expect(page.driver.user_agent).to eq('TestBrowser')
    end
  end
end
