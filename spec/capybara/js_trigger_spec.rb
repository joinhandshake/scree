require 'spec_helper'

describe Capybara::Selenium::Node do
  it 'triggers an event' do
    visit '/js-playground'

    find('a.home-link').trigger('click')
    expect(page).to have_current_path('/')
  end
end
