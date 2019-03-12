lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scree/version'

Gem::Specification.new do |spec|
  spec.name    = 'scree'
  spec.version = Scree::VERSION
  spec.authors = ['Rob Trame']
  spec.email   = ['rtrame@joinhandshake.com']

  spec.summary     = 'Useful extensions for Capybara/Selenium/Rack testing'
  spec.description = 'A collection of extensions and tools for more advanced '\
                     'interactions in Capybara/Selenium/Rack test environments'

  spec.homepage = 'https://github.com/joinhandshake/scree'
  spec.license  = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the
  # 'allowed_push_host' to allow pushing to a single host or delete this section
  # to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = [spec.homepage, 'CHANGELOG.md'].join('/')
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  spec.add_development_dependency 'awesome_print', '>= 2.0.0pre', '< 3.0'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'haml'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'puma'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.61'
  spec.add_development_dependency 'sinatra', '~> 2.0'
  spec.add_development_dependency 'sinatra-contrib'

  # Hard cap on some dependencies because we're extending some internals
  spec.add_runtime_dependency 'aasm'
  spec.add_runtime_dependency 'capybara', '>= 3.9', '< 3.13'
  spec.add_runtime_dependency 'chrome_remote', '>= 0.2.0'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1'
  spec.add_runtime_dependency 'rack', '~> 2.0'
  spec.add_runtime_dependency 'selenium-webdriver', '>= 3.13', '< 3.142'
end
