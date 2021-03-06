module Scree
  module RspecMatchers
    require 'rspec/expectations'

    RSpec::Matchers.define :have_errors do |*expected|
      match do |actual|
        actual = resolve(actual)
        return false if actual.error_messages.empty?

        if expected.any?
          expect(raw_messages(actual)).to match_array(expected)
        else
          expect(actual.error_messages).to_not be_empty
        end
      end

      failure_message do |actual|
        actual_errors  = raw_messages(actual)
        missing_errors = expected - actual_errors
        extra_errors   = actual_errors - expected

        if missing_errors
          "did not receive expected errors:\n#{format_messages(missing_errors)}"
        end

        if extra_errors
          "received unexpected errors:\n#{format_messages(extra_errors)}"
        end
      end

      failure_message_when_negated do |actual|
        actual_errors = raw_messages(actual)
        formatted     = format_messages(actual_errors)
        "expected no Javascript errors, received:\n#{formatted}"
      end

      def raw_messages(actual)
        actual.error_messages.map(&:message)
      end

      def format_messages(messages)
        messages.map do |message|
          "  - #{message}\n"
        end
      end

      def resolve(actual)
        if actual.respond_to? :page
          actual.page.driver
        elsif actual.respond_to? :driver
          actual.driver
        else
          actual
        end
      end
    end

    RSpec::Matchers.define :receive_http_response do |pattern = /.*/, wait: Capybara.default_max_wait_time|
      match do |actual|
        assert_proc(actual)
        current_events =
          page.driver.browser.fetch_events('Network.responseReceived')

        success = page.driver.browser.wait_for_http_response(pattern, wait, &actual)

        @actual_events =
          page.driver.browser.fetch_events('Network.responseReceived') - current_events

        success
      end

      match_when_negated do |actual|
        assert_proc(actual)
        current_events =
          page.driver.browser.fetch_events('Network.responseReceived')

        success = page.driver.browser.wait_for_http_response(pattern, wait, negated: true, &actual)

        @actual_events =
          page.driver.browser.fetch_events('Network.responseReceived') - current_events

        success
      end

      failure_message do
        event_urls =
          if @actual_events.any?
            @actual_events.map { |event| event.dig('response', 'url') }.join(', ')
          else
            'none'
          end

        "expected an HTTP response matching #{pattern.inspect}, but received #{event_urls}"
      end

      # If you're trying to say that a URL comes up, but not with the substring,
      # e.g. removing a filter from a search, it's better to use regex negative
      # lookahead with expect { ... }.to receive_http_response.
      # This is because to_not waits for the timeout, however, if you know there
      # will be a response, but it won't have something, you can return once
      # that response is made and validated.
      failure_message_when_negated do
        "did not expect an HTTP response matching #{pattern.inspect}, "\
        'but one was received'
      end

      def assert_proc(actual)
        return true if actual.is_a? Proc

        error_message = "expected Block, but received #{actual.class.name}"
        raise RSpec::Expectations::ExpectationNotMetError(error_message)
      end

      supports_block_expectations
    end
  end
end
