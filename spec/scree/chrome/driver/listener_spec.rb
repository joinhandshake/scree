require 'spec_helper'
require 'scree'

describe Scree::Chrome::Driver::Listener do
  let(:driver) do
    instance_double(
      'Websocket::Driver::Client',
      on:    nil,
      parse: nil
    )
  end
  let(:socket) do
    instance_double(
      'Scree::Chrome::Driver::Socket',
      read: nil
    )
  end
  let(:listener) { described_class.new(driver, socket) }

  describe '#initialize' do
    it 'registers stop callbacks' do
      listener # Init lazy-loaded instance

      expect(driver).to have_received(:on).with(:close)
      expect(driver).to have_received(:on).with(:error)
    end

    it 'does not start a listen thread when initialized' do
      current_listen_thread = listener.instance_variable_get(:@listen_thread)
      expect(current_listen_thread).to be_nil
    end
  end

  describe '#listen' do
    it 'returns true if started listening' do
      expect(listener.listen).to be_truthy
      listener.stop
    end

    it 'returns true if already listening' do
      listener.listen
      expect(listener.listen).to be_truthy
      listener.stop
    end

    it 'starts a new thread to listen' do
      listener.listen
      current_listen_thread = listener.instance_variable_get(:@listen_thread)

      expect(current_listen_thread).not_to be_nil
      listener.stop
    end

    it 'does not start a new thread if already listening' do
      listener.listen
      current_listen_thread = listener.instance_variable_get(:@listen_thread)

      listener.listen
      check_listen_thread = listener.instance_variable_get(:@listen_thread)

      expect(check_listen_thread).to eq(current_listen_thread)
      listener.stop
    end

    it 'reads socket data' do
      socket_data = {
        data: { method: 'Console.messageAdded', params: { message: 'test' } }
      }.to_json

      allow(socket).to receive(:read).and_return(socket_data)

      listener.listen
      sleep 0.0001 # Make sure our thread can run at least one loop
      listener.stop

      expect(driver).to have_received(:parse).with(socket_data).at_least(:once)
    end

    it 'automatically exits when EOF is reached' do
      allow(socket).to receive(:read).and_raise(EOFError)

      listener.listen
      sleep 0.0001 # Make sure our thread can run at least one loop

      expect(listener).to be_stopped
    end
  end

  describe '#pause' do
    it 'puts thread to sleep'
    it 'allows thread to finish parsing'
  end

  describe '#stop' do
    it 'pauses the thread before killing'
    it 'kills the thread if alive'
    it 'does not attempt to kill dead threads'
    it 'raises an error if the thread fails to stop'
    it 're-joins the thread'
  end

  describe '#listening?' do
    it 'returns true if thread is running'
    it 'returns false if thread has not started'
    it 'returns false if thread is paused'
    it 'returns false if thread is stopped'
  end

  describe '#paused?' do
    it 'returns true if thread is paused'
    it 'returns false if thread has not started'
    it 'returns false if thread is running'
    it 'returns false if thread is stopped'
  end

  describe '#stopped?' do
    it 'returns true if thread is stopped'
    it 'returns false if thread has not started'
    it 'returns false if thread is running'
    it 'returns false if thread is paused'
  end
end
