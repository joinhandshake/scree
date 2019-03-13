require 'concurrent'
require 'scree/chrome/driver'

module Scree
  module Chrome
    class Client
      def initialize(url)
        @url = url
        perform_setup
      end

      # Blocking; only returns when response received
      def ask(command, params = {})
        msg_id  = Random.new.rand(2**16)
        promise = ::Concurrent::Promises.resolvable_future

        @listeners[msg_id] = promise

        @connection.write({ method: command, params: params, id: msg_id }.to_json)
        promise.wait(Capybara.default_max_wait_time)

        @listeners.delete(msg_id)
        promise.value!
      end

      # Non-blocking; response is discarded
      def tell(command, params = {})
        msg_id = Random.new.rand(2**16)
        @connection.write({ method: command, params: params, id: msg_id }.to_json)
      end

      def add_handler(event_name, &block)
        uuid = SecureRandom.uuid
        @handlers[event_name][uuid] = block
        uuid
      end

      def add_global_handler(&block)
        uuid = SecureRandom.uuid
        @global_handlers[uuid] = block
        uuid
      end

      def remove_handler(uuid, event_name: nil)
        block =
          if event_name == :global
            @global_handlers.delete(uuid)
          elsif event_name
            @handlers[event_name].delete(uuid)
          else
            # We should not have any duplicate UUIDs, but handle that
            # improbable corner-case anyway
            all_handlers =
              @handlers.keys.map do |key|
                @handlers[key].delete(uuid)
              end
            all_handlers << @global_handlers.delete(uuid)
            all_handlers.flatten!
            all_handlers.compact!
            all_handlers.one? && all_handlers.first || all_handlers
          end

        block
      end

      # This only resets internal state handled by Scree; it does not currently
      # change/reset anything in Chrome
      def reset!
        return unless @connection.started?

        @connection.stop
        perform_setup
      end

      def schema
        return @schema if @schema

        uri      = URI.parse(@url)
        response = Net::HTTP.get(uri.host, '/json/protocol/', uri.port)
        @schema = JSON.parse(response)
      rescue JSON::ParserError
        STDERR.puts('WARN: Unable to fetch Chrome DevTools Protocol schema')
        @schema = {}
      end

      private

      def perform_setup
        @listeners = Concurrent::Map.new
        @handlers  =
          Concurrent::Map.new do |map, event_name|
            map[event_name] = Concurrent::Map.new
          end

        # Handle all events; intended for handlers that need to filter other
        # than on event name
        @global_handlers = Concurrent::Map.new

        @connection = Driver.connect(@url, &event_handler)
      end

      def event_handler
        proc do |event|
          message    = JSON.parse(event)
          event_name = message['method']
          message_id = message['id']

          # Normally, for messages with an id, we expect a 'result' field, and
          # messages with a method, we expect a 'params' field. However, this
          # can sometimes end up with confusing results, so store both (where
          # available) just to be sure.
          result = message
          params = message['params'] || message['result']

          @listeners[message_id]&.fulfill(result) if message_id
          run_handlers(event_name, params)
        rescue JSON::ParserError
          STDERR.puts "Expected JSON, receivied:\n#{message}"
        end
      end

      def run_handlers(event_name, params)
        @handlers[event_name].each_value do |handler|
          # Maybe just call w/ new thread?
          Concurrent::Promises.future(params, &handler).run
        end

        @global_handlers.each_value do |handler|
          Concurrent::Promises.future(event_name, params, &handler).run
        end
      end
    end
  end
end
