module Scree
  module Utils
    class Network
      def initialize(browser)
        @browser = browser

        init_attrs
      end

      def intercept_requests(filters, filtered_args, &block)
        stop_interception

        @intercept_filters  = process_filters(filters)
        @intercept_callback = block
        @intercept_args   ||= filtered_args

        resume_interception
      end

      def pause_interception
        return false unless @intercept_uuid

        @browser.off_cdp_event(intercept_uuid)
      ensure
        resume_all_requests
        @intercept_uuid = nil
      end

      def resume_interception
        return false unless @intercept_callback

        start_interception
      end

      def stop_interception
        return false unless @intercept_callback

        pause_interception if @intercept_uuid
      ensure
        init_attrs
      end
      alias unblock_urls stop_interception

      def block_urls(urls, error_reason: 'BlockedByClient')
        request_patterns = build_request_patterns(
          'urlPattern'        => urls,
          'interceptionStage' => 'HeadersReceived'
        )

        intercept_requests(request_patterns, 'errorReason' => error_reason)
      end

      private

      def init_attrs
        @intercept_filters     = []
        @intercept_url_filters = []
        @intercept_callback    = nil
        @intercept_args        = nil
        @intercept_uuid        = nil
      end

      def build_request_patterns(request_patterns)
        patterns = [request_patterns['urlPattern']].flatten.product(
          request_patterns[['resourceType']].flatten,
          request_patterns[['interceptionStage']].flatten
        )

        patterns.map do |url, type, stage|
          request_pattern = {}
          request_pattern['urlPattern'] << url if url
          request_pattern['resourceType'] << type if type
          request_pattern['interceptionStage'] << stage if stage
          request_pattern
        end
      end

      def process_filters(filters)
        @intercept_filters = []
        filters.each do |filter|
          @intercept_url_filters << calculate_filter(filter['urlPattern'])
          filter['urlPattern'] = wildcard_url(filter['urlPattern'])
        end
      end

      def wildcard_url(url)
        uri = URI.parse(url)

        # If no scheme, wildcard the beginning, since it's a partial URL
        url = '*' + url if uri.scheme.nil?

        # If no path, we may or may not end up with a trailing '/'. Chrome only
        # allows wildcards '*' (zero or more), and '?' (exactly one). To handle
        # this, we'll have to catch all requests to domain and handle them with
        # regex in the callback.
        url.delete_suffix('/') + '*'
      end

      def calculate_filter(filter_url)
        filter_data = URI.split(filter_url)
        host_regex  = /
          (
            (?:[\p{L}\p{N}][\p{L}\p{N}]*.)+[\p{L}\p{N}]{2,}|        # IDN
            ((?:(?:^|\.)(?:\d|[1-9]\d|1\d{2}|2[0-4]\d|25[0-5])){4}) # IP
          )
        /x

        [/\w+/, nil, host_regex, /\d*/, nil, %r{/?}, nil, nil, nil].
          zip(filter_data).map do |default, filter|
            filter&.length&.positive? && filter || default
          end
      end

      def start_interception
        @intercept_uuid = listen_for_interceptions
        @browser.execute_cdp!(
          'Network.setRequestInterception',
          'patterns' => @intercept_filters
        )
      end

      # This callback will perform the same on all intercepted requests. This is
      # because Chrome doesn't allow you to register multiple interceptions, nor
      # merge existing ones, so we're overwriting what, if anything is there
      # anyway.
      def listen_for_interceptions
        @browser.on_cdp_event('Network.requestIntercepted') do |message|
          id       = message['interceptionId']
          url      = message.dig('request', 'url')
          response = filter_url?(url, filtered: block_request(id))
          error    = response.dig('error', 'message')

          raise error if error
        end
      rescue StandardError
        pause_interception
        raise
      end

      def filter_url?(url)
        @intercept_url_filters.any? do |filter|
          URI.split(url).zip(filter).all? do |part, filter_part|
            filter_part && (part || '').match?(filter_part) || part.nil?
          end
        end
      end

      def continue_request(interception_id, filtered: false)
        params = { 'interceptionId' => interception_id }
        params.merge!(@intercept_args) if filtered

        @browser.execute_cdp!('Network.continueInterceptedRequest', params)
      rescue StandardError
        false # Usually they've already been continued, so we're ok
      end

      def resume_all_requests
        # There are some things that can go wrong here, and we want to resume
        # any pending interceptions _no matter what_.
        begin
          @browser.execute_cdp!(
            'Network.setRequestInterception',
            'patterns' => []
          )
        rescue StandardError
          # If the above fails, modify our filters so they allow anything
          @intercept_url_filters = []
        end

        @browser.
          cdp_event_cache('Network.requestIntercepted').
          all? { |message| continue_request(message['interceptionId']) }
      end
    end
  end
end
