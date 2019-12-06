require 'capybara/dsl'
require 'capybara/selenium/driver'
require 'scree/utils/network'

module Scree
  module Patches
    module CapybaraMethods
      def console_messages
        browser.cdp_event_cache('Runtime.consoleAPICalled')
      end

      def error_messages
        console_messages.select { |msg| msg['type'] == 'error' }
      end
      alias js_errors error_messages

      def header(key, value)
        browser.execute_cdp!(
          'Network.setExtraHTTPHeaders',
          headers: { key => value }
        )
      end

      def response_headers
        response['headers']
      end

      def status_code
        response['status']
      end

      def with_blocked_urls(*urls)
        blocker = Scree::Utils::Network.new(browser)
        blocker.block_urls(urls)
        yield
      ensure
        blocker.unblock_urls
      end

      def user_agent
        evaluate_script('navigator.userAgent')
      end

      def with_user_agent(user_agent)
        browser.execute_cdp!(
          'Network.setUserAgentOverride',
          'userAgent': user_agent.to_s
        )
        yield
      ensure
        browser.execute_cdp!('Network.setUserAgentOverride', 'userAgent': nil)
      end

      private

      def response
        browser.cdp_event_cache('Network.responseReceived').max_by do |event|
          event.dig('response', 'url') == browser.current_url &&
            event['timestamp']
        end['response'] || {}
      end
    end
  end
end

Capybara::Selenium::Driver.prepend Scree::Patches::CapybaraMethods

# The below simply forwards calls to the named methods to the driver,
# which is similar to how it's implemented in Capybara, but thinner.
NEW_SESSION_METHODS =
  %i[
    console_messages
    error_messages
    header
    response_headers
    status_code
    with_blocked_urls
    with_user_agent
  ].freeze

NEW_SESSION_METHODS.each do |method|
  ::Capybara::Session.define_method(
    method,
    ::Capybara::Selenium::Driver.instance_method(method)
  )
end
