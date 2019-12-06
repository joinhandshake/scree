module Scree
  module Chrome
    module Driver
      class Listener
        STATUS_OPTIONS = %i[listening paused stopped].freeze

        def initialize(driver, socket)
          @driver      = driver
          @socket      = socket
          @pause_mutex = Mutex.new

          @driver.on(:close) { stop }
          @driver.on(:error) { stop }
        end

        def listen
          run_listen_thread
        end

        def pause
          pause_listen_thread
        end

        def stop
          kill_listen_thread
        end

        def listening?
          status == :listening
        end

        def paused?
          status == :paused
        end

        def stopped?
          status == :stopped
        end

        private

        def status
          return nil if @listen_thread.nil?

          case @listen_thread.status
          when 'run'
            :listening
          when 'sleep'
            :paused
          when 'aborting', false, nil
            :stopped
          end
        end

        def run_listen_thread
          @pause_mutex.unlock if @pause_mutex.locked?

          return true if @listen_thread&.alive?

          @listen_thread =
            Thread.new do # rubocop:disable ThreadSafety/NewThread
              loop do
                # Ensure we don't interrupt parses
                @pause_mutex.synchronize do
                  @driver.parse(@socket.read)
                end
              rescue EOFError
                Thread.exit
              end
            end

          @listen_thread.alive?
        end

        def pause_listen_thread
          @pause_mutex.lock
        end

        def kill_listen_thread
          # Finish any in-progress reads/parses
          @pause_mutex.lock unless @pause_mutex.locked?
          @listen_thread.kill if @listen_thread.alive?

          if @listen_thread.alive?
            @listen_thread.raise('Timed out waiting for thread to stop')
          end

          @listen_thread.join
        end
      end
    end
  end
end
