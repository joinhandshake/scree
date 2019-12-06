require 'capybara'
require 'concurrent'
require 'concurrent-edge'

module Scree
  module Chrome
    class Client
      DEFAULT_OPTS = {
        domains: []
      }.freeze

      def initialize(host, port, opts = {})
        @opts = opts
        perform_setup(host, port)
      end

      # Blocking; only returns when response received
      def ask(command, params = {})
        msg_id  = Random.new.rand(2**16)
        promise = Concurrent::Promises.resolvable_future
        message = { method: command, params: params, id: msg_id }.to_json

        @listeners[msg_id] = promise

        @connection.write(message)
        promise.wait(Capybara.default_max_wait_time)

        @listeners.delete(msg_id)
        promise.value!
      end

      # Non-blocking; response is discarded
      def tell(command, params = {})
        msg_id = Random.new.rand(2**16)
        message = { method: command, params: params, id: msg_id }.to_json
        @connection.write(message)
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

      def wait_for_event(event_name, wait: 2, &block)
        promise = Concurrent::Promises.resolvable_future
        promise = promise.then(&block) if block_given?

        uuid = add_handler(event_name) do |event|
          promise.fulfill(event) if promise.pending?
        end

        promise.wait(wait)
        remove_handler(uuid, event_name)
        promise.value!
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

        uri      = URI.parse(@connection.url)
        response = Net::HTTP.get(uri.host, '/json/protocol/', uri.port)
        @schema  = JSON.parse(response)
      rescue JSON::ParserError
        STDERR.puts('WARN: Unable to fetch Chrome DevTools Protocol schema')
        @schema = {}
      end

      private

      def perform_setup(host, port)
        @listeners = Concurrent::Map.new
        @handlers  =
          Concurrent::Map.new do |map, event_name|
            map[event_name] = Concurrent::Map.new
          end
        @caches =
          Concurrent::Map.new do |map, event_name|
            map[event_name] = Concurrent::Array.new
          end

        # Handle all events; intended for handlers that need to filter other
        # than on event name
        @global_handlers = Concurrent::Map.new

        @connection = Scree::Chrome::Driver.connect(host, port, &event_handler)
      end

      def enable_domains
        @opts[:domains].each do |domain|
          error = ask("#{domain}.enable").dig('error', 'message')
          raise error if error

          # Currently, we automatically enable caches for enabled domain events
          add_global_handler do |event_name, event|
            next unless event_name.start_with?(domain)

            @caches[event_name] << event
          end
        end
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
