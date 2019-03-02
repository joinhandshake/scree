require 'spec_helper'

describe Capybara::Session do
  describe '#with_user_agent' do
    it 'uses specified user-agent within block' do
      test_ua = 'TestFramework/1.0'

      with_user_agent(test_ua) do
        visit '/check-headers'
        headers = JSON.parse(find('.current-headers').text)
        expect(headers['HTTP_USER_AGENT']).to eq(test_ua)
      end
    end

    it 'correctly resets user-agent after block' do
      visit '/check-headers'

      test_ua = 'TestFramework/1.0'
      real_ua = JSON.parse(find('.current-headers').text)['HTTP_USER_AGENT']

      with_user_agent(test_ua) do
        refresh
      end

      refresh
      current_ua = JSON.parse(find('.current-headers').text)['HTTP_USER_AGENT']

      expect(current_ua).to eq(real_ua)
    end
  end

  %i[console_messages error_messages].each do |driver_method|
    describe "##{driver_method}" do
      it "calls the driver's #{driver_method} method" do
        visit '/'

        expect(page.driver).to receive(driver_method)

        page.send(driver_method)
      end
    end
  end
end
