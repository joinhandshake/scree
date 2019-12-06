require 'spec_helper'
require 'scree/rspec_matchers'

describe RspecMatchers do
  describe '#have_errors' do
    let(:error_driver) do
      instance_double(
        'Capybara::Selenium::Driver',
        error_messages: [{ 'message' => 'Test message' }]
      )
    end
    let(:pass_driver) do
      instance_double(
        'Capybara::Selenium::Driver',
        error_messages: []
      )
    end

    it 'passes if error messages are present' do
      expect { expect(error_driver).to have_errors }.not_to raise_error
    end

    it 'passes if expected error messages are present' do
      expect do
        expect(error_driver).to have_errors('Test message')
      end.not_to raise_error
    end

    it 'fails if no error messages are present' do
      expect do
        expect(pass_driver).to have_errors
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it 'fails if expected error messages are not present' do
      expect do
        expect(error_driver).to have_errors('Test message', 'Other message')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it 'fails if unexpected error messages are present' do
      driver_double = instance_double(
        'Capybara::Selenium::Driver',
        error_messages: [
          { 'message' => 'Test message' },
          { 'message' => 'Other message' }
        ]
      )

      expect do
        expect(driver_double).to have_errors('Test message')
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    context 'when negated' do
      it 'passes if no error messages are present' do
        expect { expect(pass_driver).not_to have_errors }.not_to raise_error
      end

      it 'passes if expected not-present error messages are not present' do
        expect do
          expect(pass_driver).not_to have_errors('Test message')
        end.not_to raise_error
      end

      it 'passes if unexpected not-present error messages are present' do
        expect do
          expect(error_driver).not_to have_errors('Other message')
        end.not_to raise_error
      end

      it 'fails if error messages are present' do
        expect do
          expect(error_driver).not_to have_errors
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'fails if expected not-present error messages are present' do
        expect do
          expect(error_driver).not_to have_errors('Test message')
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end
  end

  describe '#receive_http_response' do
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
      end.not_to raise_error
    end

    it 'passes if multiple http responses received in block' do
      expect(page.driver.browser).to(mock_net_events(test_event, other_event))

      expect do
        expect do
          # noop
        end.to receive_http_response
      end.not_to raise_error
    end

    it 'passes if matching http response received in block' do
      expect(page.driver.browser).to(mock_net_events(test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.not_to raise_error
    end

    it 'passes if matching http response received twice in block' do
      expect(page.driver.browser).to(mock_net_events(test_event, test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.not_to raise_error
    end

    it 'passes if matching and non-matching http responses received in block' do
      expect(page.driver.browser).to(mock_net_events(other_event, test_event))

      expect do
        expect do
          # noop
        end.to receive_http_response(%r{^https:\/\/test\.example\.com})
      end.not_to raise_error
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
