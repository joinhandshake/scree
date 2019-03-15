require 'time'
require 'webrick/cookie'

module MissingApiMethods
  def response_headers
    response['headers']
  end

  def status_code
    response['status']
  end

  # Interface from capybara-webkit

  def console_messages
    browser.fetch_events('Runtime.consoleAPICalled')
  end

  def error_messages
    console_messages.select { |msg| msg['type'] == 'error' }
  end
  alias js_errors error_messages

  def cookies
    browser.manage.all_cookies
  end

  def set_cookie(cookie)
    cookie =
      if cookie.is_a? String
        parse_cookie(cookie)
      else
        normalize_cookie(cookie)
      end

    browser.manage.add_cookie(cookie)
  end

  def delete_cookie(name)
    browser.manage.delete_cookie(name)
  end

  def clear_cookies
    browser.manage.delete_all_cookies
  end

  def header(key, value)
    params = { headers: { key => value } }
    send_cdp('Network.setExtraHTTPHeaders', params)
  end

  def with_blocked_urls(*urls)
    uuid = send_blocked_urls(urls)

    yield
  ensure
    clear_blocked_urls(uuid)
  end

  def extra_http_headers=(headers)
    send_cdp('Network.setExtraHTTPHeaders', 'headers': headers)
  end

  def user_agent
    evaluate_script('navigator.userAgent')
  end

  def user_agent=(user_agent)
    send_cdp('Network.setUserAgentOverride', 'userAgent': user_agent.to_s)
  end

  private

  def execute_cdp(cmd, params = {})
    browser.execute_cdp(cmd, params)
  end

  def send_cdp(cmd, params = {})
    browser.send_cdp(cmd, params)
  end

  # Cribbed from https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/array/wrap.rb
  def array_wrap(obj)
    if obj.nil?
      []
    elsif obj.respond_to?(:to_ary)
      obj.to_ary
    else
      [obj]
    end
  end

  def response
    responses =
      browser.fetch_events('Network.responseReceived').select do |event|
        event.dig('response', 'url') == browser.current_url
      end

    responses.max_by { |resp| resp['timestamp'] }['response'] || {}
  end

  def parse_cookie(cookie)
    cookie = WEBrick::Cookie.parse_set_cookie(cookie)
    fields = %i[name value expires max_age domain path secure]

    fields.each_with_object({}) do |field, cookie_hash|
      value = cookie.send(field)
      cookie_hash[field] = value unless value.nil?
    end
  end

  # Cookies can come in all kinds of hash formats (depending on what gem
  # created the hash). We'll try and transform it here.
  def normalize_cookie(cookie)
    known_attrs =
      %w[name value expires max_age domain path http_only httponly secure]

    # Ensure we have string keys for easier processing/lookup
    cookie =
      cookie.each_with_object({}) do |(key, value), memo|
        new_key   = key.to_s.downcase.tr('-', '_')
        new_value = value.is_a?(Array) && value.first || value
        next if value.nil?

        if known_attrs.include?(new_key)
          memo[new_key.to_sym] = new_value
        else
          memo[:name] = key
          memo[:value] = new_value
        end
      end

    expires = cookie.delete('expires')
    cookie[:expires] = Time.parse(expires.to_s) unless expires.nil?

    cookie
  end

  # Providing regex/wildcarded URLs is not currently supported, due to the
  # extreme jank-factor of CDP's URL filtering
  def send_blocked_urls(blocked_urls)
    request_intercept_uuid = register_blocked_url_callback(blocked_urls)
    url_patterns = build_url_patterns(blocked_urls)

    patterns = url_patterns.map { |url| { 'urlPattern' => url, 'interceptionStage' => 'HeadersReceived' } }
    send_cdp('Network.setRequestInterception', 'patterns' => patterns)
    request_intercept_uuid
  end

  def clear_blocked_urls(uuid)
    browser.
      instance_variable_get(:@cdp_bridge).
      remove_handler(uuid, event_name: 'Network.requestIntercepted')
    send_cdp('Network.setRequestInterception', 'patterns' => [])
    continue_all_requests!
  end

  # This callback will just block all intercepted requests. This is because
  # Chrome doesn't allow you to register multiple interceptions, nor merge
  # existing ones, so we're overwriting what, if anything is there anyway.
  def register_blocked_url_callback(blocked_urls)
    require 'awesome_print'
    browser.on_cdp_event('Network.requestIntercepted') do |message|
      id       = message['interceptionId']
      url      = message.dig('request', 'url')
      response =
        if blocked_urls.any? { |blocked_url| filter_url?(url, blocked_url) }
          block_request(id)
        else
          continue_request(id)
        end

      error = response.dig('error', 'message')

      raise error if error
    rescue StandardError
      continue_all_requests!
      raise
    end
  end

  def build_url_patterns(blocked_urls)
    blocked_urls.map do |url|
      uri = URI.parse(url)

      # If no scheme, wildcard the beginning, since it's a partial URL
      url = '*' + url if uri.scheme.nil?

      # If no path, we may or may not end up with a trailing '/'. Chrome only
      # allows wildcards '*' (zero or more), and '?' (exactly one). To handle
      # this, we'll have to catch all requests to domain and handle them with
      # regex in the callback.
      url.delete_suffix('/') + '*'
    end
  end

  def filter_url?(url, filter_url)
    URI.split(url).zip(calculate_filters(filter_url)).all? do |part, filter|
      if filter
        (part || '').match?(filter) # Allows us to pass when filter allows empty
      else
        part.nil?
      end
    end
  end

  def calculate_filters(filter_url)
    filter_data = URI.split(filter_url)
    host_regex  = /
      (
        (?:[\p{L}\p{N}][\p{L}\p{N}]*.)+[\p{L}\p{N}]{2,}|        # IDN
        ((?:(?:^|\.)(?:\d|[1-9]\d|1\d{2}|2[0-4]\d|25[0-5])){4}) # IP
      )
    /x
    defaults = [/\w+/, nil, host_regex, /\d*/, nil, %r{/?}, nil, nil, nil]

    filter_data.zip(defaults).map do |filter, default|
      filter&.length&.positive? && filter || default
    end
  end

  def block_request(interception_id, with: 'BlockedByClient')
    send_cdp(
      'Network.continueInterceptedRequest',
      'interceptionId' => interception_id,
      'errorReason'    => with
    )
  end

  def continue_request(interception_id)
    send_cdp(
      'Network.continueInterceptedRequest',
      'interceptionId' => interception_id
    )
  end

  # If something went wrong, we don't want to hang due to an error, instead
  # we'll just dump all requests
  def continue_all_requests!
    ids = browser.
          fetch_events('Network.requestIntercepted').
          map { |message| message['interceptionId'] }

    ids.each do |id|
      continue_request(id)
    rescue StandardError
      false # Usually they've already been continued, but we don't care
    end
  end
end

::Capybara::Selenium::Driver.prepend MissingApiMethods
