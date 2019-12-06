require 'spec_helper'
require 'scree/patches/js_trigger_shim'

describe JSTriggerShim do
  it 'prepends to Capybara::Selenium::Node'

  describe '#trigger' do
    it 'triggers a JS event' do
      visit '/js-playground'

      find('a.home-link').trigger('click')
      expect(page).to have_current_path('/')
    end
  end
end
