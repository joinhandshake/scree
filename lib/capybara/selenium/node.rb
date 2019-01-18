module Capybara
  module Selenium
    class Node
      def trigger(event)
        browser.execute_script(
          '$(arguments[0]).trigger("arguments[1]")',
          native,
          event.to_s
        )
      end
    end
  end
end
