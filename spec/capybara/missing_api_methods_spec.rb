require 'spec_helper'
require 'uri'

describe Capybara::Selenium::Driver do
  describe '#response_headers' do
    it 'gets response headers' do
      custom_headers = { 'X-TEST-HEADER' => 'test value' }

      visit '/check-headers'
      fill_in 'custom_headers', with: custom_headers.to_json
      click_on 'Submit'

      find('.page-loaded')

      expect(page.response_headers['X-TEST-HEADER']).to eq 'test value'
    end
  end

  describe '#status_code' do
    it 'gets the status code' do
      visit '/'
      expect(page.status_code).to eq 200
    end
  end

  describe '#console_messages' do
    it 'gets console messages' do
      custom_messages = { 'log' => 'everything is awesome' }

      visit '/console-log'
      fill_in 'log_messages', with: custom_messages.to_json
      click_on 'Submit'

      find('.page-loaded') # Ensure console has time to fire.

      log_message = page.console_messages.first.args.first.value

      expect(log_message).to eq 'everything is awesome'
    end
  end

  describe '#error_messages' do
    it 'gets error messages' do
      custom_messages = { 'error' => 'everything is awful' }

      visit '/console-log'
      fill_in 'log_messages', with: custom_messages.to_json
      click_on 'Submit'

      find('.page-loaded') # Ensure console has time to fire.

      log_message = page.error_messages.first.args.first.value

      expect(log_message).to eq 'everything is awful'
    end
  end

  describe '#cookies' do
    it 'gets the cookies' do
      visit '/'
      expect(page.cookies.first[:value]).to eq 'root-cookie'
    end
  end

  describe '#set_cookie' do
    it 'sets a cookie' do
      visit '/'

      test_cookie = {
        name:    'scree',
        value:   'test-cookie',
        path:    '/',
        domain:  URI.parse(current_url).hostname,
        expires: nil,
        secure:  false
      }

      expect(page.cookies.count).to eq 1
      expect(page.cookies.first[:value]).to eq 'root-cookie'

      page.set_cookie test_cookie
      visit '/check-cookies'

      parsed_cookies = JSON.parse(page.text)

      expect(parsed_cookies.count).to eq 2
      expect(parsed_cookies['scree']).to eq 'test-cookie'
    end
  end

  describe '#clear_cookies' do
    it 'clears all cookies' do
      visit '/'
      expect(page.cookies.first[:value]).to eq 'root-cookie'

      page.clear_cookies
      visit '/check-cookies'

      expect(JSON.parse(page.text)).to be_empty
    end
  end

  describe '#header' do
    # This does not work right with CDP; find another way.
    it 'sets extra header' do
      visit '/check-headers'

      page.header('X-TEST-HEADER', 'request-test')
      visit '/check-headers'

      # Extra headers only applies to requests from page itself
      fill_in 'custom_headers', with: '{}'
      click_on 'Submit'

      request_headers = JSON.parse(page.find('.request-headers').text)

      expect(request_headers['HTTP_X_TEST_HEADER']).to eq 'request-test'
    end
  end
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
