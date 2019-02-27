module Capybara
  module Selenium
    module RspecMatchers
      require 'rspec/expectations'
      require 'timeout'

      RSpec::Matchers.define :have_errors do |*expected|
        match do |actual|
          actual = resolve(actual)
          return false if actual.error_messages.empty?

          expect(actual.error_messages).to contain_exactly(expected)
        end

        failure_message do |actual|
          missing_errors = expected - actual
          extra_errors = actual - expected

          if missing_errors
            "did not receive expected errors:\n#{format_messages(missing_errors)}"
          end

          if extra_errors
            "received unexpected errors:\n#{format_messages(extra_errors)}"
          end
        end

        failure_message_when_negated do |actual|
          "expected no Javascript errors, received:\n#{error_messages_for(actual)}"
        end

        def format_messages(messages)
          messages.map do |m|
            actual.error_messages(obj).map do |m|
              "  - #{m.message}"
            end.join("\n")
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
          unless actual.is_a? Proc
            raise RSpec::Expectations::ExpectationNotMetError("expected Block, but received #{actual.class.name}")
          end

          wait_for_response(pattern, wait, &actual)
        end

        failure_message do
          "expected an HTTP response matching #{pattern}, but none received"
        end

        # If you're trying to say that a URL comes up, but not with the substring,
        # e.g. removing a filter from a search, it's better to use regex negative
        # lookahead with expect { ... }.to receive_http_response.
        # This is because to_not waits for the timeout, however, if you know there
        # will be a response, but it won't have something, you can return once that
        # response is made and validated.
        failure_message_when_negated do
          "did not expect an HTTP response matching #{pattern}, but one was made"
        end

        def wait_for_response(pattern, wait)
          begin_index = browser.cdp_events['Network.responseReceived'].count
          yield

          Timeout::timeout(wait) {
            loop do
              received = browser.cdp_events['Network.responseReceived'][begin_index..-1].any? do |event|
                event.response.url.match? pattern
              end

              break if received
            end
          }
        rescue Timeout::Error
          false
        end

        supports_block_expectations
      end
    end
  end
end
