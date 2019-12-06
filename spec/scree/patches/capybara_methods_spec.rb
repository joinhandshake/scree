require 'spec_helper'
require 'scree/patches/capybara_methods'

describe CapybaraMethods do
  it 'prepends to Capybara::Selenium::Driver'

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

  describe '#with_blocked_urls' do
    let(:blocked_url) do
      Capybara.current_session.send(:server_url) + '/check-headers'
    end
    let(:allowed_url) do
      Capybara.current_session.send(:server_url) + '/js-playground'
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
      other_path   = '/js-playground'

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

  describe '#user_agent' do
    it 'returns the current user_agent' do
      visit '/'

      expect(page.driver.user_agent).to include('HeadlessChrome')
    end
  end

  describe '#with_user_agent' do
    it 'uses specified user-agent within block' do
      test_ua = 'TestFramework/1.0'

      with_user_agent(test_ua) do
        visit '/check-headers'
        headers = JSON.parse(find('.current-headers').text)
        expect(headers['HTTP_USER_AGENT']).to eq(test_ua)
      end
    end

    it 'correctly resets user-agent after block' do
      visit '/check-headers'

      test_ua = 'TestFramework/1.0'
      real_ua = JSON.parse(find('.current-headers').text)['HTTP_USER_AGENT']

      with_user_agent(test_ua) do
        refresh
      end

      refresh
      current_ua = JSON.parse(find('.current-headers').text)['HTTP_USER_AGENT']

      expect(current_ua).to eq(real_ua)
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

    expect(failure).not_to be_falsey
    expect(failure['errorText']).to eq 'net::ERR_BLOCKED_BY_CLIENT'
    expect(failure['blockedReason']).to eq 'inspector'
  end

  def expect_no_failure(url)
    failure = find_load_failure(url)

    expect(failure).to be_falsey
  end
end
