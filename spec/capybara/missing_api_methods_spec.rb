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

      log_message = page.console_messages.first['args'].first['value']

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

      log_message = page.error_messages.first['args'].first['value']

      expect(log_message).to eq 'everything is awful'
    end
  end

  describe '#cookies' do
    it 'gets the cookies' do
      visit '/'
      expect(page.driver.cookies.first[:value]).to eq 'root-cookie'
    end
  end

  describe '#set_cookie' do
    it 'sets a cookie from hash' do
      visit '/'

      test_cookie = {
        name:    'scree',
        value:   'test-cookie',
        path:    '/',
        domain:  URI.parse(current_url).hostname,
        expires: nil,
        secure:  false
      }

      expect(page.driver.cookies.count).to eq 1
      expect(page.driver.cookies.first[:value]).to eq 'root-cookie'

      page.driver.set_cookie test_cookie
      visit '/check-cookies'

      parsed_cookies = JSON.parse(page.text)

      expect(parsed_cookies.count).to eq 2
      expect(parsed_cookies['scree']).to eq 'test-cookie'
    end

    it 'sets a cookie from string' do
      visit '/'

      domain      = URI.parse(current_url).hostname
      expiry      = (Time.now + 32_400).utc
      test_cookie = "scree=test-cookie; Domain=#{domain}; "\
                    "Expires=#{expiry}; Path=/"

      expect(page.driver.cookies.count).to eq 1
      expect(page.driver.cookies.first[:value]).to eq 'root-cookie'

      page.driver.set_cookie test_cookie
      visit '/check-cookies'

      parsed_cookies = JSON.parse(page.text)

      expect(parsed_cookies.count).to eq 2
      expect(parsed_cookies['scree']).to eq 'test-cookie'
    end
  end

  describe '#clear_cookies' do
    it 'clears all cookies' do
      visit '/'
      expect(page.driver.cookies.first[:value]).to eq 'root-cookie'

      page.driver.clear_cookies
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

  describe '#with_blocked_urls' do
    let(:blocked_url) do
      Capybara.current_session.send(:server_url) + '/check-headers'
    end
    let(:allowed_url) do
      Capybara.current_session.send(:server_url) + '/check-cookies'
    end

    it 'blocks given url' do
      page.driver.with_blocked_urls(blocked_url) do
        visit blocked_url
        expect_failure(blocked_url)
      end
    end

    it 'does not block other urls' do
      page.driver.with_blocked_urls(blocked_url) do
        visit blocked_url
        expect_failure(blocked_url)

        visit allowed_url
        expect_no_failure(allowed_url)
      end
    end

    it 'blocks partial urls' do
      blocked_path = '/check-headers'
      other_path   = '/check-cookies'

      page.driver.with_blocked_urls(blocked_path) do
        visit blocked_path
        expect_failure(blocked_path)

        visit other_path
        expect_no_failure(other_path)
      end
    end

    it 'unblocks urls after execution if block given' do
      page.driver.with_blocked_urls(blocked_url) do
        visit blocked_url
        expect_failure(blocked_url)
      end

      visit blocked_url
      expect_no_failure(blocked_url)
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

  def find_load_failure(url)
    browser = page.driver.browser
    request = browser.
              fetch_events('Network.requestWillBeSent').
              max_by do |event|
                next 0 unless event['documentURL'].match?(url)

                event['timestamp']
              end

    return nil if request.nil?

    browser.fetch_events('Network.loadingFailed').find do |event|
      event['requestId'] == request['requestId']
    end
  end

  def expect_failure(url)
    failure = find_load_failure(url)

    expect(failure).to_not be_falsey
    expect(failure['errorText']).to eq 'net::ERR_BLOCKED_BY_CLIENT'
    expect(failure['blockedReason']).to eq 'inspector'
  end

  def expect_no_failure(url)
    failure = find_load_failure(url)

    expect(failure).to be_falsey
  end
end
