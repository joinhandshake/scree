module Capybara
  module Selenium
    class Driver
      def response_headers
        response['headers']
      end

      def status_code
        response['status']
      end

      # Interface from capybara-webkit

      def console_messages
        browser.cdp_events['Runtime.consoleAPICalled']
      end

      def error_messages
        console_messages.select { |msg| msg['type'] == 'error' }
      end

      def cookies
        browser.manage.all_cookies
      end

      def set_cookie(opts = {})
        # Convert capybara-webkit args to what Selenium needs
        opts = CGI::Cookie.parse(cookie) if opts.is_a? String
        browser.manage.add_cookie(opts)
      end

      def clear_cookies
        browser.manage.delete_all_cookies
      end

      def header(key, value)
        browser.execute_cdp('Network.setExtraHTTPHeaders', { key => value })
      end

      private

      def response
        browser.cdp_events['Network.responseReceived'].select do |event|
          event['response']['url'] == browser.current_url
        end.last
      end
    end
  end
end
