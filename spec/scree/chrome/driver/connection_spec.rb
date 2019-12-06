require 'ostruct'
require 'spec_helper'
require 'scree'
require 'websocket/driver'

describe Scree::Chrome::Driver::Connection do
  describe '#initialize' do
    it 'is initially closed' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:listening?).and_return(false)

      expect(connection).not_to be_started
    end

    context 'with handler passed' do
      it 'registers given handler with websocket' do
        ws_client     = init_doubles[:ws_client]
        message_block = proc { |msg| msg.to_s }

        described_class.new('http://test:1234', &message_block)
        expect(ws_client).to have_received(:on).with(:message) do |_, &block|
          expect(block.call(OpenStruct.new(data: 1))).to eq('1')
        end
      end
    end

    context 'with no handler passed' do
      it 'registers default handler with websocket' do
        ws_client  = init_doubles[:ws_client]
        connection = described_class.new('http://test:1234')

        expect(ws_client).to have_received(:on).with(:message) do |_, &block|
          block.call(OpenStruct.new(data: 'test'))
          expect(connection.instance_variable_get(:@events).pop).to eq('test')
        end
      end
    end

    it 'registers callbacks' do
      ws_client   = init_doubles[:ws_client]
      event_names = %i[open close error message]
      described_class.new('http://test:1234')

      expect(ws_client).to(
        have_received(:on).
        with(satisfy { |arg| event_names.delete(arg) }).
        exactly(4).times
      )
    end
  end

  describe '#start' do
    it 'opens the websocket' do
      ws_client = init_doubles[:ws_client]
      described_class.new('http://test:1234').start

      expect(ws_client).to have_received(:start)
    end

    it 'starts the listener' do
      listener = init_doubles[:listener]
      described_class.new('http://test:1234').start

      expect(listener).to have_received(:listen)
    end
  end

  describe '#stop' do
    it 'pauses the listener before closing websocket' do
      doubles   = init_doubles
      listener  = doubles[:listener]
      ws_client = doubles[:ws_client]

      described_class.new('http://test:1234').stop

      expect(listener).to have_received(:pause).ordered
      expect(ws_client).to have_received(:close).ordered
    end

    it 'closes the websocket' do
      ws_client = init_doubles[:ws_client]

      described_class.new('http://test:1234').stop

      expect(ws_client).to have_received(:close)
    end
  end

  describe '#started?' do
    it 'returns true if listening and currently open' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      connection.start
      allow(listener).to receive(:listening?).and_return(true)

      expect(connection).to be_started
    end

    it 'returns false if listening stopped' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      connection.start
      allow(listener).to receive(:listening?).and_return(false)

      expect(connection).not_to be_started
    end

    it 'returns false if not currently open' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:listening?).and_return(false)

      expect(connection).not_to be_started
    end
  end

  describe '#paused?' do
    it 'delegates to listener' do
      listener = init_doubles[:listener]

      described_class.new('http://test:1234').paused?

      expect(listener).to have_received(:paused?)
    end
  end

  describe '#stopped?' do
    it 'delegates to listener' do
      listener = init_doubles[:listener]

      described_class.new('http://test:1234').stopped?

      expect(listener).to have_received(:stopped?)
    end
  end

  describe '#initializing?' do
    it 'returns true if listener has no status' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:listening?).and_return(false)
      allow(listener).to receive(:paused?).and_return(false)
      allow(listener).to receive(:stopped?).and_return(false)

      expect(connection).to be_initializing
    end

    it 'returns false if listener is listening' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:listening?).and_return(true)

      expect(connection).not_to be_initializing
    end

    it 'returns false if listener is paused' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:paused?).and_return(true)

      expect(connection).not_to be_initializing
    end

    it 'returns false if listener is stopped' do
      listener   = init_doubles[:listener]
      connection = described_class.new('http://test:1234')

      allow(listener).to receive(:stopped?).and_return(true)

      expect(connection).not_to be_initializing
    end
  end

  describe '#write' do
    it 'delegates to websocket' do
      ws_client  = init_doubles[:ws_client]
      connection = described_class.new('http://test:1234')

      connection.write('test message')

      expect(ws_client).to have_received(:text).with('test message')
    end
  end

  def init_doubles # rubocop:disable Metrics/MethodLength
    socket = instance_double(
      'Scree::Chrome::Driver::Socket',
      write: nil
    )
    ws_client = instance_double(
      'Websocket::Driver::Client',
      start: nil,
      close: nil,
      text:  nil,
      on:    nil
    )
    listener = instance_double(
      'Scree::Chrome::Driver::Listener',
      listen:     nil,
      pause:      nil,
      listening?: false,
      paused?:    false,
      stopped?:   false
    )

    init_return_doubles(socket, ws_client, listener)
    { socket: socket, ws_client: ws_client, listener: listener }
  end

  def init_return_doubles(socket, ws_client, listener)
    allow(Scree::Chrome::Driver::Socket).to receive(:new).and_return(socket)
    allow(WebSocket::Driver).to receive(:client).and_return(ws_client)
    allow(Scree::Chrome::Driver::Listener).to receive(:new).and_return(listener)
  end
end
