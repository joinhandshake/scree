require 'scree/chrome'
require 'selenium-webdriver'

module Scree
  module Patches
    module SeleniumDriver
      def initialize(opts = {})
        cdp_opts = opts.delete(:cdp_options) { {} }

        super

        @cdp_bridge = Scree::Chrome.client_for(
          debugger_uri.host,
          debugger_uri.port,
          cdp_opts
        )
      end

      def execute_cdp(cmd, params = {})
        @cdp_bridge.ask(cmd, params)
      end

      def execute_cdp!(cmd, params = {})
        @cdp_bridge.tell(cmd, params)
      end

      def on_cdp_event(event_name, &block)
        @cdp_bridge.add_handler(event_name, &block)
      end

      def wait_for_cdp_event(event_name, filter, wait: 2)
        @cdp_bridge.wait_for_event(event_name, filter, wait: wait)
      end

      def off_cdp_event(uuid)
        @cdp_bridge.remove_handler(uuid)
      end

      def cdp_event_cache(event_name)
        @cdp_bridge.event_cache[event_name]
      end

      def reset_cdp!
        @cdp_bridge.reset!
      end

      private

      # Specifying a debugger address ourselves can interfere with Selenium and
      # vice-versa, so we'll just piggyback on whatever they end up using.
      def debugger_uri
        return @debugger_uri if @debugger_uri

        debugger_address =
          @bridge.http.
          call(:get, "/session/#{@bridge.session_id}", nil).
          payload.
          dig('value', 'goog:chromeOptions', 'debuggerAddress')

        unless debugger_address.match?(%r{^\w+://})
          debugger_address.prepend('http://')
        end

        @debugger_uri = URI.parse(debugger_address)
      end
    end
  end
end

::Selenium::WebDriver::Chrome::Driver.prepend Scree::Patches::SeleniumDriver
