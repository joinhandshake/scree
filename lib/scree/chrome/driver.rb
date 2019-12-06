module Scree
  module Chrome
    module Driver
      root = File.expand_path('driver', __dir__)

      autoload :Connection, File.join(root, 'connection')
      autoload :Listener, File.join(root, 'listener')
      autoload :Socket, File.join(root, 'socket')

      # Takes a block, just the same as connect_with_handler, but is optional
      # here. Both exist purely for the sake of clarity of caller's intent.
      def self.connect(host, port, &block)
        debug_url = fetch_debug_url(host, port)
        raise 'debug target not found' if debug_url.nil?

        start_connection(
          Scree::Chrome::Driver::Connection.new(debug_url, &block)
        )
      end

      class << self
        private

        def start_connection(connection)
          connection.start

          # Errored state should actually raise
          if connection.stopped?
            raise connection.error || 'Failed to connect to Chrome'
          end

          connection
        end

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
end
