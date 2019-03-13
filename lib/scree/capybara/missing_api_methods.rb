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
    request_intercept_uuid = register_blocked_url_callback
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
  def register_blocked_url_callback
    browser.on_cdp_event('Network.requestIntercepted') do |message|
      response =
        send_cdp(
          'Network.continueInterceptedRequest',
          'interceptionId' => message['interceptionId'],
          'errorReason'    => 'BlockedByClient'
        )

      error = response.dig('error', 'message')
      raise error if error
    rescue StandardError
      continue_all_requests!
      raise
    end
  end

  # Chrome doesn't take actual regex, just wildcards '*' and '?'
  def build_url_patterns(blocked_urls)
    blocked_urls.map do |url|
      uri  = URI.parse(url)
      host = uri.host.delete_prefix('www.')
      path = uri.path

      if path&.empty?
        # CDP doesn't allow for making trailing '/' optional, so we just allow
        # any trailing character and filter it out with our regex.
        # Similarly with leading 'www.' vs other subdomains and https vs http
        "http*://*#{host}?"
      else
        "http*://*#{host}/#{path}"
      end
    end
  end

  # If something went wrong, we don't want to hang due to an error, instead
  # we'll just dump all requests
  def continue_all_requests!
    ids = browser.
          fetch_events('Network.requestIntercepted').
          map { |message| message['interceptionId'] }

    ids.each do |id|
      send_cdp(
        'Network.continueInterceptedRequest',
        'interceptionId' => id
      )
    rescue StandardError
      next # Usually they've already been continued, but we don't care
    end
  end
end

::Capybara::Selenium::Driver.prepend MissingApiMethods
