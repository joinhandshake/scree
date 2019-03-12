require 'spec_helper'
require 'scree/rspec_matchers'
require 'ostruct'

describe Scree::RspecMatchers do
  describe 'have_errors' do
    it 'passes if error messages are present' do
      message_double = double('Message', message: 'Test message')
      driver_double  = double('Driver', error_messages: [message_double])

      expect { expect(driver_double).to have_errors }.to_not raise_error
    end

    it 'passes if expected error messages are present' do
      message_double = double('Message', message: 'Test message')
      driver_double  = double('Driver', error_messages: [message_double])

      expect do
        expect(driver_double).to have_errors('Test message')
      end.to_not raise_error
    end

    it 'fails if no error messages are present' do
      driver_double = double('Driver', error_messages: [])

      expect do
        expect(driver_double).to have_errors
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it 'fails if expected error messages are not present' do
      message_double = double('Message', message: 'Test message')
      driver_double  = double('Driver', error_messages: [message_double])

      expect do
        expect(driver_double).to have_errors('Test message', 'Other message')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it 'fails if unexpected error messages are present' do
      message_doubles =
        [
          double('Message', message: 'Test message'),
          double('Message', message: 'Other message')
        ]
      driver_double = double('Driver', error_messages: message_doubles)

      expect do
        expect(driver_double).to have_errors('Test message')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    context 'negated' do
      it 'passes if no error messages are present' do
        driver_double = double('Driver', error_messages: [])

        expect { expect(driver_double).to_not have_errors }.to_not raise_error
      end

      it 'passes if expected not-present error messages are not present' do
        driver_double = double('Driver', error_messages: [])

        expect do
          expect(driver_double).to_not have_errors('Test message')
        end.to_not raise_error
      end

      it 'passes if unexpected not-present error messages are present' do
        message_double = double('Message', message: 'Test message')
        driver_double  = double('Driver', error_messages: [message_double])

        expect do
          expect(driver_double).to_not have_errors('Other message')
        end.to_not raise_error
      end

      it 'fails if error messages are present' do
        message_double = double('Message', message: 'Test message')
        driver_double  = double('Driver', error_messages: [message_double])

        expect do
          expect(driver_double).to_not have_errors
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'fails if expected not-present error messages are present' do
        message_double = double('Message', message: 'Test message')
        driver_double  = double('Driver', error_messages: [message_double])

        expect do
          expect(driver_double).to_not have_errors('Test message')
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end
  end

  describe 'receive_http_response' do
    let(:test_event) do
      { 'response' => { 'url' => 'https://test.example.com' } }
    end
    let(:other_event) do
      { 'response' => { 'url' => 'https://other.example.com' } }
    end

    it 'passes if http response received in block' do
      expect(page.driver.browser).to(mock_net_events(test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response
      end.to_not raise_error
    end

    it 'passes if multiple http responses received in block' do
      expect(page.driver.browser).to(mock_net_events(test_event, other_event))

      expect do
        expect do
          # noop
        end.to receive_http_response
      end.to_not raise_error
    end

    it 'passes if matching http response received in block' do
      expect(page.driver.browser).to(mock_net_events(test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.to_not raise_error
    end

    it 'passes if matching http response received twice in block' do
      expect(page.driver.browser).to(mock_net_events(test_event, test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.to_not raise_error
    end

    it 'passes if matching and non-matching http responses received in block' do
      expect(page.driver.browser).to(mock_net_events(other_event, test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.to_not raise_error
    end

    it 'fails if no http response received in block' do
      expect(page.driver.browser).to(mock_net_events)

      expect do
        expect do
          # noop
        end.to receive_http_response
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it 'fails if no matching http response received in block' do
      expect(page.driver.browser).to(mock_net_events(other_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    def mock_net_events(*events)
      receiver = receive(:on_cdp_event).with('Network.responseReceived')

      events.each do |event|
        receiver = receiver.and_yield(event)
      end

      receiver
    end
  end
end
