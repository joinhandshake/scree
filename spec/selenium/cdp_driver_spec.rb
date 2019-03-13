require 'spec_helper'

describe Selenium::WebDriver::Chrome::Driver do
  describe '#initialize' do
    it 'sets up a CDP bridge'
  end

  describe '#execute_cdp' do
    it 'executes a CDP command synchronously'
  end

  describe '#send_cdp' do
    it 'executes a CDP command asynchronously'
  end

  describe '#on_cdp_event' do
    it 'registers a CDP event callback'
  end

  describe '#wait_for_cdp_event' do
    it 'blocks execution pending a CDP event callback'
    it 'times out if no CDP event callback received'
  end

  describe '#remove_handler' do
    it 'removes a CDP event callback'
  end

  describe '#reset!' do
    it 'clears all cached CDP events'
    it 'resets the status of the CDP bridge'
  end

  describe '#fetch_events' do
    it 'retrieves all events with the given name'
  end
end
