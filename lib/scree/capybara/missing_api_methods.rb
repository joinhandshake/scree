module MissingApiMethods
  def response_headers
    response.headers
  end

  def status_code
    response.status
  end

  # Interface from capybara-webkit

  def console_messages
    browser.cdp_events['Runtime.consoleAPICalled']
  end

  def error_messages
    console_messages.select { |msg| msg.type == 'error' }
  end
  alias js_errors error_messages

  def cookies
    browser.manage.all_cookies
  end

  def set_cookie(opts = {})
    # Convert capybara-webkit args to what Selenium needs
    opts = CGI::Cookie.parse(cookie) if opts.is_a? String
    browser.manage.add_cookie(opts)
  end

  def clear_cookies
    browser.manage.delete_all_cookies
  end

  # TODO: This is finicky in CDP. There might be a better way.
  def header(key, value)
    params = { headers: { key => value } }
    browser.execute_cdp('Network.setExtraHTTPHeaders', params)
  end

  # This ends up just stalling the request which eventually raises a
  # Net::Timeout after a few minutes, but causes the browser to stall entirely,
  # which is not ideal for tests.
  def blocked_urls=(_urls)
    raise NotImplementedError
    # execute_cdp('Network.setBlockedURLs', 'urls': array_wrap(urls))
  end

  def extra_http_headers=(headers)
    browser.execute_cdp('Network.setExtraHTTPHeaders', 'headers': headers)
  end

  def user_agent
    evaluate_script('navigator.userAgent')
  end

  def user_agent=(user_agent)
    browser.execute_cdp('Network.setUserAgentOverride', 'userAgent': user_agent.to_s)
  end

  private

  def execute_cdp(cmd, params = {})
    browser.execute_cdp(cmd, params)
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
      browser.cdp_events['Network.responseReceived'].select do |event|
        event.response.url == browser.current_url
      end

    responses.max_by(&:timestamp).response || {}
  end
end

::Capybara::Selenium::Driver.prepend MissingApiMethods
