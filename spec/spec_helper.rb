require 'bundler/setup'
require 'rspec/expectations'
require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'support/test_app'
require 'nokogiri'
require 'scree'

RSpec.configure do |config|
  config.include Capybara::DSL

  Capybara.register_driver :chrome_headless do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.args << '--headless'
    options.args << '--disable-gpu'
    options.args << '--window-size=1920,1440'
    options.args << '--remote-debugging-port=4444'

    capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
      loggingPrefs: {
        browser: 'ALL',
        client: 'ALL',
        driver: 'ALL',
        server: 'ALL'
      }
    )

    cdp_options = {
      domains: %w[Network Runtime],
      events:  ['Network.responseReceived', 'Runtime.consoleAPICalled']
    }

    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      clear_local_storage: true,
      desired_capabilities: capabilities,
      options: options,
      cdp_options: cdp_options
    )
  end

  Capybara.javascript_driver = :chrome_headless

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

Capybara.configure do |config|
  config.default_driver = :chrome_headless
  config.app = TestApp
  config.save_path = File.join(Dir.pwd, 'save_path_tmp')
end
