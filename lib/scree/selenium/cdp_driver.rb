# frozen_string_literal: true

require 'chrome_remote'
require 'concurrent'
require 'securerandom'
require 'timeout'

module CdpDriver
  # This only encludes domains that support "enable".
  CDP_DOMAINS = %w[
    Accessibility
    Animation
    ApplicationCache
    Console
    CSS
    Database
    Debugger
    DOM
    DOMSnapshot
    DOMStorage
    Fetch
    HeadlessExperimental
    HeapProfiler
    IndexedDB
    Inspector
    LayerTree
    Log
    Network
    Overlay
    Page
    Performance
    Profiler
    Runtime
    Security
    ServiceWorker
  ].freeze

  def initialize(opts = {})
    # This is intended to accept both enable_cdp: true as well as an array
    # of cdp domains, e.g. enable_cdp: ['Network', 'Console']
    cdp_opts = opts.delete(:cdp_options)

    super

    debugging_uri = @service.debugging_uri
    @cdp_bridge =
      ChromeRemote.client(host: debugging_uri.host, port: debugging_uri.port)

    handler_hash =
      Hash.new do |hash, event_name|
        handle_any = proc { |result| cdp_events[event_name].unshift(result) }
        hash[event_name] = [handle_any]
      end

    # The chrome_remote handler code is kinda touchy, and we want to just grab
    # all enabled anyway.
    @cdp_bridge.instance_variable_set(:@handlers, handler_hash)

    enable_cdp_domains(cdp_opts[:domains]) if cdp_opts.key?(:domains)

    Thread.new do
      @cdp_bridge.listen
    rescue EOFError
      puts 'CDP connection closed'
    end
  end

  def execute_cdp(cmd, **params)
    bridge.send_command(cmd: cmd, params: params)
  end

  def on_cdp_event(event_name, &block)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    @cdp_bridge.on(event_name, &block)
  end

  def wait_for_cdp_event(event_name = nil)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    yield wait_for_event(event_name) if block_given?
  end

  # TODO: raise if attempting to get an event that's not being recorded
  def cdp_events
    @cdp_events ||=
      Concurrent::Map.new do |map, event|
        map[event] = Concurrent::Array.new
      end
  end

  private

  def enable_cdp_domains(domains)
    domains.each do |domain|
      next unless CDP_DOMAINS.include?(domain)

      @cdp_bridge.send_cmd "#{domain}.enable"
    end
  end

  def register_cdp_listeners(events)
    events.each do |event|
      on_cdp_event(event) { |result| cdp_events[event].unshift(result) }
    end
  end

  def wait_for_event(event_name)
    current_count = cdp_events[event_name].count

    Timeout.timeout(5, Timeout::Error, 'Timed out waiting for CDP event') do
      loop do
        # Possible race condition?
        if cdp_events[event_name].count > current_count
          return cdp_events.first
        end
      end
    end
  end
end

::Selenium::WebDriver::Chrome::Driver.prepend CdpDriver
