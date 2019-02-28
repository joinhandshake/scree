require 'scree/version'
require 'capybara'
require 'selenium/webdriver'

# We must load up EVERYTHING to properly prepend it all
Dir[File.join('lib', 'scree', '**', '*.rb')].each do |file|
  require file.delete_suffix('.rb').sub(/^lib./, '')
end

module Scree; end
