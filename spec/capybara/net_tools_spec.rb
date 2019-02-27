require 'spec_helper'

describe Capybara::Selenium::Driver::ChromeDriver do
  # This does not work right with CDP; find another way.
  describe '#blocked_urls=' do
    it 'blocks specified urls' do
      expect do
        page.driver.blocked_urls = ['https://google.com']
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#extra_http_headers=' do
    it 'sends extra http headers' do
      visit '/check-headers'
      page.driver.extra_http_headers = { 'X-TEST-EXTRA-HEADER' => 'test' }

      click_on 'Submit'

      current_headers = JSON.parse(page.find('.request-headers').text)
      expect(current_headers['HTTP_X_TEST_EXTRA_HEADER']).to eq 'test'
    end
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
