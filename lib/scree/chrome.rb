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
        return @client if @client

        debug_uri = fetch_debug_url(host, port)
        raise "debug target not found" if debug_uri.nil?

        @client = Client.new(debug_uri)
      end

      private

      def fetch_debug_url(host, port)
        response = Net::HTTP.get(host, '/json', port)
        response = JSON.parse(response)

        debugger_urls =
          response.lazy.map do |obj|
            obj['type'] == 'page' && obj['webSocketDebuggerUrl'] || nil
          end
        debugger_urls.select { |obj| obj }.take(1).first
      end
    end
  end
end
