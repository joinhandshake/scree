require 'bundler/setup'
require 'rspec/expectations'
require 'capybara'
require 'capybara/rspec'
require 'selenium/webdriver'
require 'support/test_app'
require 'scree'
require 'scree/rspec_matchers'

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include Scree::RspecMatchers

  Capybara.register_driver :chrome_headless do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.args << '--headless'
    options.args << '--disable-gpu'
    options.args << '--window-size=1920,1440'
    options.args << '--remote-debugging-port=4444'

    capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
      loggingPrefs: {
        browser: 'ALL',
        client:  'ALL',
        driver:  'ALL',
        server:  'ALL'
      }
    )

    cdp_options = {
      domains: %w[Network Runtime],
      events:  ['Network.responseReceived', 'Runtime.consoleAPICalled']
    }

    Capybara::Selenium::Driver.new(
      app,
      browser:              :chrome,
      clear_local_storage:  true,
      desired_capabilities: capabilities,
      options:              options,
      cdp_options:          cdp_options
    )
  end

  Capybara.register_driver :chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.args << '--window-size=1920,1440'
    options.args << '--remote-debugging-port=4444'

    capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
      loggingPrefs: {
        browser: 'ALL',
        client:  'ALL',
        driver:  'ALL',
        server:  'ALL'
      }
    )

    cdp_options = {
      domains: %w[Network Runtime],
      events:  ['Network.responseReceived', 'Runtime.consoleAPICalled']
    }

    Capybara::Selenium::Driver.new(
      app,
      browser:              :chrome,
      clear_local_storage:  true,
      desired_capabilities: capabilities,
      options:              options,
      cdp_options:          cdp_options
    )
  end

  Capybara.javascript_driver = :chrome_headless

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Make sure we don't have old events bleeding over.
  config.after(:each) do
    page.driver.browser.reset_cdp_cache!
  end
end

Capybara.configure do |config|
  config.default_driver = :chrome_headless
  config.app = TestApp
  config.save_path = File.join(Dir.pwd, 'save_path_tmp')
end
