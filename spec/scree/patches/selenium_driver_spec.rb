require 'spec_helper'
require 'scree/patches/selenium_driver'

describe SeleniumDriver do
  it 'prepends to Selenium::WebDriver::Chrome::Driver'

  describe '#initialize' do
    it 'sets up a CDP bridge'
  end

  describe '#execute_cdp' do
    it 'executes a CDP command synchronously'
  end

  describe '#execute_cdp!' do
    it 'executes a CDP command asynchronously'
  end

  describe '#on_cdp_event' do
    it 'registers a CDP event callback'
  end

  describe '#wait_for_cdp_event' do
    it 'blocks execution pending a CDP event callback'
  end

  describe '#off_cdp_event' do
    it 'removes a CDP event callback'
  end

  describe '#cdp_event_cache' do
    it 'returns an array of cdp events'
  end
end
