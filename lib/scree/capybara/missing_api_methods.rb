require 'time'
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

  def set_cookie(cookie)
    # Convert capybara-webkit args to what Selenium needs
    cookie = CGI::Cookie.parse(cookie) if cookie.is_a? String

    # Cookies can come in all kinds of hash formats (depending on what gem
    # created the hash). We'll try and transform it here.

    cookie_hash = {}

    # Ensure we have string keys for easier processing/lookup
    cookie = cookie.collect { |key, value| [key.to_s, value] }.to_h

    %w[path domain secure httponly].each do |key|
      value = cookie.delete(key)
      value =
        if value.is_a? Array
          value.first
        else
          value
        end

      cookie_hash[key.to_sym] = value unless value.nil?
    end

    cookie_hash[:name] = cookie.delete('name') { cookie.keys.first }

    value = cookie.delete('value') { cookie.delete(cookie_hash[:name]) }
    cookie_hash[:value] =
      if value.is_a? Array
        value.one? && value.first || value.to_a
      else
        value
      end

    expires = cookie.delete('expires')
    cookie_hash[:expires] = Time.parse(expires.to_s) unless expires.nil?

    browser.manage.add_cookie(cookie_hash)
  end

  def delete_cookie(name)
    browser.manage.delete_cookie(name)
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
