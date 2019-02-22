require 'spec_helper'

describe Selenium::WebDriver::Chrome::Driver do
  describe '#initialize' do
    it 'sets up a CDP bridge'
  end

  describe '#execute_cdp' do
    it 'executes a CDP command'
  end

  describe '#on_cdp_event' do
    it 'registers a CDP event callback'
  end

  describe '#wait_for_cdp_event' do
    it 'blocks execution pending a CDP event callback'
    it 'times out if no CDP event callback received'
  end

  describe '#cdp_events' do
    it 'contains a record of previous CDP events'
  end
end
