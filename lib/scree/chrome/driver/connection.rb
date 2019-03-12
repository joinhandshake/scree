require 'websocket/driver'
require 'scree/chrome/driver/listener'
require 'scree/chrome/driver/socket'

module Scree
  module Chrome
    module Driver
      class Connection
        attr_reader :error

        def initialize(url, &block)
          @currently_open = Concurrent::AtomicBoolean.new(false)
          @event_handler  = block
          @socket         = Scree::Chrome::Driver::Socket.new(url)
          @driver         = ::WebSocket::Driver.client(@socket)
          @listener       = Listener.new(@driver, @socket)

          register_callbacks
        end

        def start
          @driver.start
          @listener.listen
        end

        def stop
          @listener.pause # Finish reads/parses before stopping driver
          @driver.close
        end

        def started?
          @listener.listening? && @currently_open
        end

        def paused?
          @listener.paused?
        end

        def stopped?
          @listener.stopped?
        end

        def initializing?
          !@listener.listening? && !@listener.paused? && !@listener.stopped?
        end

        def write(message)
          @driver.text(message)
        end

        private

        def register_callbacks
          @driver.on(:open) do |_event|
            @currently_open.make_true
          end

          @driver.on(:close) do |event|
            @currently_open.make_false
            handle_error(event.message) if event.code != 1000
          end

          @driver.on(:error) do |event|
            @currently_open.make_false
            handle_error(event)
          end

          @driver.on(:message) do |event|
            event_data = event.data
            next @event_handler.call(event_data) if @event_handler

            process_event(event_data)
          end
        end

        def handle_error(error)
          @error = error.is_a?(StandardError) ? error : RuntimeError.new(error)
          raise @error
        end

        # Default event handler, only called if no block given to constructor
        def process_event(event)
          # Limit channel capacity to ensure we don't get too much milk and
          # block if buffer is full. The websocket gem we're using uses
          # eventmachine under the hood, so this should be ok, but if we
          # switch, make sure these callbacks do not happen synchronously
          @events ||= Concurrent::Promises::Channel.new(4)
          @events.push(event).wait!
        end
      end
    end
  end
end
