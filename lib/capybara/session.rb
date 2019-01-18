module Capybara
  class Session
    SESSION_METHODS += %i[with_user_agent].freeze
    DSL_METHODS = NODE_METHODS + SESSION_METHODS + MODAL_METHODS

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
  end
end
