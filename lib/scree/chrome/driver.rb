require 'websocket/driver'
require 'scree/chrome/socket'

module Scree
  module Chrome
    class Driver
      def initialize(url)
        @socket  = ChromeRemote::Socket.new(url)
        @driver  = ::WebSocket::Driver.client(socket)
        @started = Concurrent::AtomicBoolean.new(false)
        @handler =
          if block_given?
            block
          else
            proc do |message|
              # Limit channel capacity to ensure we don't get too much milk and
              # block if buffer is full. The websocket gem we're using uses
              # eventmachine under the hood, so this should be ok, but if we
              # switch, make sure these callbacks do not happen synchronously
              @messages ||= Concurrent::Promises::Channel.new(4)
              @messages.push(message).wait!
            end
          end

        setup_driver
        start!
      end

      def start!
        if started?
          error = StandardError.new('Driver already started')
          return Concurrent::Promises.rejected_future(error)
        end

        Concurrent::Promises.
          future { @driver.start }.
          then { loop { break if started? } }
      end

      def stop!
        unless started?
          error = StandardError.new('Driver already stopped')
          return Concurrent::Promises.rejected_future(error)
        end

        Concurrent::Promises.
          future { @driver.close }.
          then { loop { break unless started? } }
      end

      def started?
        @started.true?
      end

      def write(message)
        @driver.text(message)
      end

      private

      def setup_driver
        @driver.on(:message) do |event|
          @handler.call(event)
        end

        @driver.on(:error, &event_handler)
        @driver.on(:close, &event_handler)
        @driver.on(:open, &event_handler)
      end

      def event_handler
        proc do |event|
          [OpenEvent, CloseEvent, StandardError].each do |klass|
            break unless event.is_a?(klass)
          end

          starting = event.is_a?(OpenEvent)
          listen(starting)
          @started.value = starting

          raise event if event.is_a?(StandardError)
          raise event.message if event.is_a?(CloseEvent) && event.code != 1000
        end
      end

      def listen(listening = true)
        return @listen = @listen&.kill unless listening

        @listen =
          case @listen&.status
          when 'run'
            @listen
          when 'sleep'
            @listen.wakeup
          when 'aborting', nil
            Thread.new do
              loop do
                sleep unless started?
                @driver.parse(@socket.read)
              end
            end
          end
      end
    end
  end
end
