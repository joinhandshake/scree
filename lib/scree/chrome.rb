# This module is largely based on the chrome_remote gem:
# https://github.com/cavalle/chrome_remote
# It does not support some of the functionality this gem requires, so this
# involved extensive changes to the logic, and embedding here for simplicity.
module Scree
  module Chrome
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

    root = File.expand_path('chrome', __dir__)

    autoload :Client, File.join(root, 'client')
    autoload :Driver, File.join(root, 'driver')

    def self.client_for(host, port, opts = {})
      Scree::Chrome::Client.new(host, port, opts)
    end
  end
end
