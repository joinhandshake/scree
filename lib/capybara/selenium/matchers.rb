module Capybara
  module Selenium
    module RspecMatchers
      RSpec::Matchers.define :have_errors do |*_expected|
        raise NotImplementedError
      end

      RSpec::Matchers.define :have_js_errors do |*_expected|
        raise NotImplementedError
        # match do |actual|
        #   return false if js_errors(actual).blank? && expected.blank?

        #   # We need to ensure all errors are matched by the expected matchers...
        #   rv = js_errors(actual).any? do |error|
        #     expected.none? { |matcher| error.match?(matcher) }
        #   end

        #   # ...and all matchers have a corresponding error
        #   rv || expected.any? do |matcher|
        #     js_errors(actual).none? { |error| error.match?(matcher) }
        #   end
        # end

        # failure_message do
        #   'expected Javascript errors, but there were none.'
        # end

        # failure_message_when_negated do |actual|
        #   "expected no Javascript errors, got:\n#{error_messages_for(actual)}"
        # end

        # def error_messages_for(obj)
        #   js_errors(obj).map do |m|
        #     "  - #{m.message}"
        #   end.join("\n")
        # end
      end

      RSpec::Matchers.define :receive_http_response do |_pattern = /.*/, _wait: Capybara.default_max_wait_time|
        raise NotImplementedError
        # match do |actual|
        #   unless actual.is_a? Proc
        #     raise RSpec::Expectations::ExpectationNotMetError("expected Block, but received #{actual.class.name}")
        #   end

        #   wait_for_http_response(pattern, wait, &actual).any?
        # rescue Timeout::Error
        #   false
        # end

        # failure_message do
        #   "expected an HTTP response matching #{pattern}, but none received"
        # end

        # # If you're trying to say that a URL comes up, but not with the substring,
        # # e.g. removing a filter from a search, it's better to use regex negative
        # # lookahead with expect { ... }.to receive_http_response.
        # # This is because to_not waits for the timeout, however, if you know there
        # # will be a response, but it won't have something, you can return once that
        # # response is made and validated.
        # failure_message_when_negated do
        #   "did not expect an HTTP response matching #{pattern}, but one was made"
        # end

        # supports_block_expectations
      end
    end
  end
end
