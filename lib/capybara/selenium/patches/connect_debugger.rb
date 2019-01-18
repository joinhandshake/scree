# frozen_string_literal: true

require 'chrome_remote'

module ConnectDebugger
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
    super
    @cdp_bridge = nil

    # This is intended to accept both enable_cdp: true as well as an array
    # of cdp domains, e.g. enable_cdp: ['Network', 'Console']
    cdp_opts = opts[:cdp]
    return unless cdp_opts && cdp_opts[:enable]

    debugging_uri = @service.debugging_uri
    @cdp_bridge =
      ChromeRemote.client(host: debugging_uri.host, port: debugging_uri.port)

    enable_cdp_domains(cdp_opts[:domains]) if cdp_opts.key?(:domains)
    register_cdp_listeners(cdp_opts[:events])
  end

  def execute_cdp(cmd, **params)
    return super unless @cdp_bridge

    @cdp_bridge.send_cmd(cmd, **params)
  end

  def on_cdp_event(event_name, &block)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    @cdp_bridge.on(event_name, &block)
  end

  def wait_for_cdp_event(event_name = nil, &block)
    raise(Error::WebDriverError, 'no debugger attached') unless @cdp_bridge

    @cdp_bridge.wait_for(event_name, &block)
  end

  # TODO: raise if attempting to get an event that's not being recorded
  def cdp_events
    @cdp_events ||= Hash.new { |hsh, event_name| hsh[event_name] = [] }
  end

  private

  def enable_cdp_domains(domains)
    domains.each do |domain|
      next unless CDP_DOMAINS.inlcude?(domain)

      @cdp_bridge.send_cmd "#{domain}.enable"
    end
  end

  def register_cdp_listeners(events)
    events.each do |event|
      on_cdp_event(event) { |result| @cdp_events[event] << result }
    end
  end
end

::Selenium::WebDriver::Chrome::Driver.prepend ConnectDebugger
