require 'capybara'
require 'concurrent/promises'

module Scree
  module RspecMatchers
    require 'rspec/expectations'

    RSpec::Matchers.define :have_errors do |*expected|
      match do |actual|
        actual = resolve_driver(actual)
        return false if actual.error_messages.empty?

        if expected.any?
          expect(raw_messages(actual)).to match_array(expected)
        else
          expect(actual.error_messages).not_to be_empty
        end
      end

      failure_message do |actual|
        missing_errors = expected - actual_errors(actual)
        extra_errors   = actual_errors(actual) - expected

        if missing_errors
          "did not receive expected errors:\n#{format_messages(missing_errors)}"
        end

        if extra_errors
          "received unexpected errors:\n#{format_messages(extra_errors)}"
        end
      end

      failure_message_when_negated do |actual|
        formatted = format_messages(actual_errors(actual))
        "expected no Javascript errors, received:\n#{formatted}"
      end
    end

    # Note on negation: If you're trying to say that a URL comes up, but not
    # with a given substring, e.g. removing a filter from a search, it's better
    # to use regex negative lookahead with the positive matcher.
    # This is because to_not waits for the timeout, however, if you know there
    # will be a response, but it won't have something, you can return once
    # that response is made and validated.
    RSpec::Matchers.define :receive_http_response do |pattern = nil, wait: Capybara.default_max_wait_time| # rubocop:disable Metrics/LineLength
      match do |actual|
        perform_match(pattern, wait, false, &actual)
      end

      match_when_negated do |actual|
        perform_match(pattern, wait, true, &actual)
      end

      failure_message do
        event_urls = @actual_urls.any? && @actual_urls.join(', ') || 'none'
        "expected an HTTP response matching #{pattern.inspect}, but received "\
        "#{event_urls}"
      end

      failure_message_when_negated do
        "expected no HTTP responses matching #{pattern.inspect}, but received "\
        "#{@match}"
      end

      def perform_match(pattern, wait, negated, &actual)
        assert_proc(actual)
        responses = collect_response_data(pattern, wait, negated, &actual)

        @actual_urls = responses[:actual_urls]
        @match       = responses[:match]
        @responses[:success]
      end

      supports_block_expectations
    end

    class << self
      private

      def actual_errors(actual)
        actual.error_messages.map(&:message)
      end

      def format_messages(messages)
        messages.map { |message| "  - #{message}\n" }
      end

      def resolve_driver(actual)
        if actual.respond_to? :page
          actual.page.driver
        elsif actual.respond_to? :driver
          actual.driver
        else
          actual
        end
      end

      def collect_response_data(pattern, wait, negated, &actual)
        pre_events =
          page.driver.browser.cdp_event_cache('Network.responseReceived')

        result =
          wait_for_http_response(pattern, wait, negated: negated, &actual)

        actual_events =
          page.driver.browser.cdp_event_cache('Network.responseReceived') -
          pre_events

        actual_urls = actual_events.map { |event| event.dig('response', 'url') }

        {
          actual_urls: actual_urls,
          match:       result.value,
          success:     result.fulfilled?
        }
      end

      def wait_for_http_response(pattern, wait, negated: false)
        promise = Concurrent::Promises.resolvable_future
        uuid    = response_listener(promise, pattern, negated)

        yield

        promise.wait(wait)
        promise
      ensure
        page.driver.browser.off_cdp_event(uuid)
      end

      def response_listener(promise, pattern, negated)
        page.driver.browser.on_cdp_event('Network.responseReceived') do |event|
          url = event.dig('response', 'url')
          if pattern.nil? || url.match?(pattern) || url.include?(pattern)
            promise.resolve(!negated, url, nil, false)
          end
        end
      end

      def assert_proc(actual)
        return true if actual.is_a? Proc

        error_message = "expected Block, but received #{actual.class.name}"
        raise RSpec::Expectations::ExpectationNotMetError(error_message)
      end
    end
  end
end
