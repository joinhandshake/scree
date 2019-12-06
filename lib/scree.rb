require 'scree/version'

module Scree
  root = File.expand_path('scree', __dir__)

  autoload :Chrome, File.join(root, 'chrome')
  autoload :Patches, File.join(root, 'patches')
  autoload :Utils, File.join(root, 'utils')
end
