module NetTools
  # This ends up just stalling the request which eventually raises a
  # Net::Timeout after a few minutes, but causes the browser to stall entirely,
  # which is not ideal for tests.
  def blocked_urls=(_urls)
    raise NotImplementedError
    # execute_cdp('Network.setBlockedURLs', 'urls': array_wrap(urls))
  end

  def extra_http_headers=(headers)
    execute_cdp('Network.setExtraHTTPHeaders', 'headers': headers)
  end

  def user_agent
    evaluate_script('navigator.userAgent')
  end

  def user_agent=(user_agent)
    execute_cdp('Network.setUserAgentOverride', 'userAgent': user_agent.to_s)
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
end

::Capybara::Selenium::Driver::ChromeDriver.prepend NetTools
