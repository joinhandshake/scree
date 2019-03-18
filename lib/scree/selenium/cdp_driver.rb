# frozen_string_literal: true

require 'chrome_remote'
require 'concurrent'
require 'concurrent-edge'
require 'ostruct'
require 'securerandom'
require 'selenium/webdriver/common/port_prober'
require 'selenium/webdriver/common/service'
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
    cdp_opts = opts.delete(:cdp_options) { {} }

    super

    @caches =
      Concurrent::Map.new do |map, event_name|
        map[event_name] = Concurrent::Array.new
      end
    @cdp_bridge =
      Scree::Chrome.client(debugger_uri.host, debugger_uri.port)

    enable_cdp_domains(cdp_opts[:domains]) if cdp_opts.key?(:domains)
  end

  def execute_cdp(cmd, params = {})
    @cdp_bridge.ask(cmd, params)
  end

  def send_cdp(cmd, params = {})
    @cdp_bridge.tell(cmd, params)
  end

  def on_cdp_event(event_name, &block)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    @cdp_bridge.add_handler(event_name, &block)
  end

  def wait_for_cdp_event(event_name, &block)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    # We could possibly chain the remove_handler on this, but passing the UUID
    # around seems a bit messy.
    promise = Concurrent::Promises.resolvable_future
    promise = promise.then(&block) if block_given?

    uuid = @cdp_bridge.add_handler(event_name) do |event|
      promise.fulfill(event) if promise.pending?
    end

    promise.wait(Capybara.default_max_wait_time)
    @cdp_bridge.remove_handler(uuid, event_name)
    promise.value!
  end

  def remove_handler(uuid)
    @cdp_bridge.remove_handler(uuid)
  end

  def reset_cdp!
    @cdp_bridge.reset!
    @caches =
      Concurrent::Map.new do |map, event_name|
        map[event_name] = Concurrent::Array.new
      end
  end

  def fetch_events(event_name)
    @caches[event_name].to_a
  end

  def wait_for_http_response(pattern, wait, negated: false)
    promise = Concurrent::Promises.resolvable_future
    uuid    =
      on_cdp_event('Network.responseReceived') do |event|
        url = event.dig('response', 'url')
        if url.match?(pattern) || url.include?(pattern) && promise.pending?
          remove_handler(uuid)
          negated && promise.reject || promise.fulfill(event)
        end
      end

    yield

    promise.wait(wait)
    remove_handler(@uuid)
    promise.fulfilled?
  end

  private

  # Specifying a debugger address ourselves can interfere with Selenium and
  # vice-versa, so we'll just piggyback on whatever they end up using.
  def debugger_uri
    return @debugger_uri if @debugger_uri

    debugger_address =
      @bridge.http.
      call(:get, "/session/#{@bridge.session_id}", nil).
      payload.
      dig('value', 'goog:chromeOptions', 'debuggerAddress')

    debugger_address.prepend('http://') unless debugger_address.match?(%r{^\w+://})
    @debugger_uri = URI.parse(debugger_address)
  end

  def enable_cdp_domains(domains)
    domains.each do |domain|
      next unless CDP_DOMAINS.include?(domain)

      @cdp_bridge.tell "#{domain}.enable"
      add_cache_listener(domain)
    end
  end

  # Currently, we automatically enable caches for enabled domain events
  def add_cache_listener(domain)
    @cdp_bridge.add_global_handler do |event_name, event|
      next unless event_name.start_with?(domain)

      @caches[event_name] << event
    end
  end
end

::Selenium::WebDriver::Chrome::Driver.prepend CdpDriver
