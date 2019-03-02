# frozen_string_literal: true

require 'chrome_remote'
require 'concurrent'
require 'ostruct'
require 'securerandom'
require 'selenium/webdriver/common/port_prober'
require 'selenium/webdriver/common/service'
require 'timeout'
require 'pry'

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
    cdp_opts = opts.delete(:cdp_options) { {} }

    super

    # Specifying a debugger address ourselves can interfere with Selenium and
    # vice-versa, so we'll just piggyback on whatever they end up using.
    debugger_address =
      @bridge.http.
              call(:get, "/session/#{@bridge.session_id}", nil).
              payload.
              dig('value', 'goog:chromeOptions', 'debuggerAddress')

    debugger_address.prepend('http://') unless debugger_address.match?(%r{^\w+://})
    debugger_uri = URI.parse(debugger_address)

    @cdp_bridge =
      ChromeRemote.client(
        host: debugger_uri.host,
        port: debugger_uri.port
      )

    enable_cdp_domains(cdp_opts[:domains]) if cdp_opts.key?(:domains)

    Thread.new do
      loop do
        msg = JSON.parse(@cdp_bridge.ws.read_msg, object_class: OpenStruct)

        event_name = msg['method']
        event_id   = msg.id

        # Normally, for messages with an id, we expect a 'result' field, and
        # messages with a method, we expect a 'params' field. However, this can
        # sometimes end up with confusing results, so store both (where
        # available) just to be sure.
        result = msg
        params = msg.params || msg.result

        cdp_events[event_id].unshift(result) if event_id
        cdp_events[event_name].unshift(params) if event_name
      rescue JSON::ParserError
        next
      end
    rescue EOFError
      puts 'CDP connection closed'
    end
  end

  def execute_cdp(cmd, **params)
    msg_id = Random.new.rand(2**16)

    @cdp_bridge.ws.send_msg({ method: cmd, params: params, id: msg_id }.to_json)
    wait_for_event(msg_id)
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
          return cdp_events[event_name].first
        end
      end
    end
  end
end

::Selenium::WebDriver::Chrome::Driver.prepend CdpDriver
