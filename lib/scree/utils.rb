require 'time'

module Scree
  module Utils
    root = File.expand_path('utils', __dir__)

    autoload :Network, File.join(root, 'network')
  end
end
