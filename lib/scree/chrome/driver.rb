require 'scree/chrome/driver/connection'

module Scree
  module Chrome
    module Driver
      # Takes a block, just the same as connect_with_handler, but is optional
      # here. Both exist purely for the sake of clarity of caller's intent.
      def self.connect(url, &block)
        @connection = Connection.new(url, &block)
        start_connection
      end

      def self.connect_with_handler(url, &block)
        raise LocalJumpError, 'no block given' unless block_given?

        @connection = Connection.new(url, block)
        start_connection
      end

      class << self
        private

        def start_connection
          @connection.start

          # Errored state should actually raise
          if @connection.stopped?
            raise @connection.error || 'Failed to connect to Chrome'
          end

          @connection
        end

        def wait_for_connect
          Timout.timeout(5, Timeout::Error, 'timed out waiting to connect') do
            loop { break if @connection.started? }
          end
        end
      end
    end
  end
end
