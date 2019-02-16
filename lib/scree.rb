require 'scree/version'

# We must load up EVERYTHING to properly prepend it all
Dir[File.join('.', '**/*.rb')].each do |file|
  require file
end

module Scree; end
