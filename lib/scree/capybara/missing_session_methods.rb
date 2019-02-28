module MissingSessionMethods
  NEW_SESSION_METHODS =
    %i[with_user_agent console_messages error_messages cookies set_cookie clear_cookies header].freeze

  def with_user_agent(user_agent_string)
    unless block_given?
      raise(
        LocalJumpError,
        '`#with_user_agent` requires a block, but none given'
      )
    end

    driver.user_agent = user_agent_string
    yield
  ensure
    driver.user_agent = nil
  end

  def console_messages
    driver.console_messages
  end

  def error_messages
    driver.error_messages
  end

  def cookies
    driver.cookies
  end

  def set_cookie(**args)
    driver.set_cookie(**args)
  end

  def clear_cookies
    driver.clear_cookies
  end

  def header(*args)
    driver.header(*args)
  end

  NEW_SESSION_METHODS.each do |method|
    ::Capybara::DSL.define_method method do |*args, &block|
      Capybara.current_session.send method, *args, &block
    end
  end
end

::Capybara::Session.prepend MissingSessionMethods
