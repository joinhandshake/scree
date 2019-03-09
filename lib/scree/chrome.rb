require 'scree/chrome/client'
require 'json'
require 'net/http'

# This module is largely based on the chrome_remote gem:
# https://github.com/cavalle/chrome_remote
# It does not support some of the functionality this gem requires, so this
# involved extensive changes to the logic, and embedding here for simplicity.
module Scree
  module Chrome
    class << self
      def client(host, port)
        debug_uri = fetch_debug_uri(host, port)

        Client.new(debug_uri)
      end

      private

      def fetch_debug_uri(host, port)
        response = Net::HTTP.get(host, '/json', port)
        response = JSON.parse(response)

        all_pages =
          response.lazy.map do |obj|
            obj['type'] == 'page' && obj['webSocketDebuggerUrl']
          end

        all_pages.find { |url| !url.nil? }
      end
    end
  end
end
