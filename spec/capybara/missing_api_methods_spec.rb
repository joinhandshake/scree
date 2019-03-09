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

    xit 'sets a cookie from string' do
      visit '/'

      domain      = URI.parse(current_url).hostname
      test_cookie = "scree=test-cookie; domain=#{domain}; path=/; expires=#{Time.now.utc}; secure=false; httponly=true"

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

  describe '#block_url' do
    # This exists so we aren't relying on logic that's tested within, although
    # it unfortunately does duplicate said logic to a certain extent.
    after(:each) do
      page.driver.instance_variable_set(:@blocked_urls, Concurrent::Array.new)
      page.driver.browser.execute_cdp(
        'Network.setRequestInterception',
        'patterns' => []
      )
    end

    it 'blocks given url' do
      page.driver.block_url('https://google.com')

      visit 'https://google.com'
      expect_failure(page.current_url)
    end

    it 'unblocks urls after execution if block given' do
      page.driver.block_url('https://bing.com') do
        visit 'https://bing.com'
        expect_failure(page.current_url)
      end

      visit 'https://bing.com'
      expect_no_failure(page.current_url)
    end
  end

  describe '#unblock_url' do
    it 'unblocks given url' do
      page.driver.block_url('https://yahoo.com')
      visit 'https://yahoo.com'

      expect_failure(page.current_url)

      page.driver.unblock_url('https://yahoo.com')
      visit 'https://yahoo.com'

      expect_no_failure(page.current_url)
    end
  end

  describe '#blocked_urls=' do
    it 'blocks specified urls' do
      expect do
        page.driver.blocked_urls = ['https://google.com']
      end.to raise_error(NotImplementedError)
    end

    it 'unblocks urls after execution if block given' do
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
    events = page.driver.browser.cdp_events
    requests =
      events['Network.requestWillBeSent'].select do |event|
        event.document_url == url
      end
    request_id = requests.max_by(&:timestamp).request_id
    events['Network.loadingFailed'].find do |event|
      event.request_id == request_id
    end
  end

  def expect_failure(url)
    failure = find_load_failure(url)

    expect(failure&.error_text).to eq 'net::ERR_BLOCKED_BY_CLIENT'
    expect(failure&.blocked_reason).to eq 'inspector'
  end

  def expect_no_failure(url)
    failure = find_load_failure(url)

    expect(failure).to be nil
  end
end
