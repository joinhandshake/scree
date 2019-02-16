module NetTools
  def blocked_urls=(*urls)
    execute_cdp('Network.setBlockedURLs', urls: urls)
  end

  def extra_http_headers=(headers)
    execute_cdp('Network.setExtraHTTPHeaders', headers: headers)
  end

  def user_agent
    execute_script('navigator.userAgent')
  end

  def user_agent=(user_agent)
    execute_cdp('Network.setUserAgentOverride', 'userAgent': user_agent)
  end
end

::Capybara::Selenium::Driver::ChromeDriver.prepend NetTools
