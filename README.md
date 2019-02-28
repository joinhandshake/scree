# Scree

Scree augments the capabilities of [Capybara](https://github.com/teamcapybara/capybara) and [Selenium](https://github.com/SeleniumHQ/selenium) to ease the transition from [capybara-webkit](https://github.com/thoughtbot/capybara-webkit). It attempts to re-implement and extend functionality from capybara-webkit that falls into one of three categories:

- Is [not well-implemented](https://stackoverflow.com/a/4753745)
- [Will never](https://github.com/seleniumhq/selenium-google-code-issue-archive/issues/141) [be implemented](https://github.com/seleniumhq/selenium-google-code-issue-archive/issues/1671)
- Involves [clunky](https://stackoverflow.com/a/40868923) [workarounds](https://stackoverflow.com/a/32723053)
- Just has a different API

This gem provides the following:

- `Capybara::Selenium::Node#trigger` ([won't be implemented](https://github.com/seleniumhq/selenium-google-code-issue-archive/issues/1671))
- `Capybara::Selenium::Driver`:
  - `#response_headers` ([won't be implemented](https://groups.google.com/forum/#!topic/selenium-users/fMSHeH9ZVqU/discussion))
  - `#status_code` ([won't be implemented](https://groups.google.com/forum/#!topic/selenium-users/fMSHeH9ZVqU/discussion))
  - `#console_messages` ([clunky workaround](https://stackoverflow.com/a/32723053))
  - `#error_messages` ([clunky workaround](https://stackoverflow.com/a/32723053))
  - `#cookies` (Different API/helpers)
  - `#set_cookie` (Different API/helpers)
  - `#header` ([clunky workaround](https://stackoverflow.com/a/40868923))
- `Scree::RspecMatchers` (Convenience)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'scree'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install scree

## Usage

This gem largely uses [module prepending](https://ruby-doc.org/core-2.5.3/Module.html#method-i-prepend) to extend the functionality of Capybara, thus essentially building it into their DSL. If you're unfamiliar with `Module#prepend`, [this excellent StackOverflow answer](<(https://stackoverflow.com/a/4471202)>) by [Jörg W Mittag](https://github.com/JoergWMittag) for a good explanation.

Because of this, these methods can be used just like any of their built-in siblings:

```ruby
## Methods on elements
find('a.home-link').trigger('click')

## Methods on session
with_user_agent('test-user-agent') do
  visit '/user-agent-example'
  page.driver.user_agent # == 'test-user-agent'
end

console_messages # array of log events
error_messages   # array of log events of type 'error'

set_cookie('raw_cookie_string') # Wrapper for page.driver.manage.add_cookie, parses cookie if string (as capybara-webkit uses)
cookies # Wapper for page.driver.manage.all_cookies
clear_cookies # Wrapper for page.driver.manage.delete_all_cookies

header('X-TEST-HEADER', 'test') # Sets extra header for next request/navigate _from this page_ (doesn't work with #visit)

## Methods on driver
page.driver.status_code # HTTP status code of most-recent request
page.driver.response_headers # Headers of most-recent request
page.driver.blocked_urls = ['https://example.com'] # Raises NotImplementedError
page.driver.extra_http_headers = { 'X-TEST-HEADER' => 'test' } # Sets extra header for next request/navigate _from this page_ (doesn't work with #visit)
page.driver.user_agent = 'test-user-agent' # Is set indefinitely, INCLUDING SUBSEQUENT SPECS; USE WITH CARE
page.driver.user_agent # == 'test-user-agent'
```

### Matchers

To use the matchers, just add it to your spec_helper, as such:

```ruby
require 'scree/rspec_matchers'

RSpec.configure do |config|
  # ...
  config.include Scree::RspecMatchers
  # ...
end
```

## Known Issues

Right now, some parts of the implementation are fairly inefficient. Specifically:

### DevTool Domains

We enable _all_ of the Chrome DevTool domains. This may have significant effects on memory usage and run-time, due to the large-scale logging of requests.

This was done pending a more developer-friendly way of enabling these, since inconsistent states can cause very buggy behavior and a frustrating experience.

### Unlimited Event Logging

We capture all events from the beginning of chromedriver's execution until the test suite is finished. This is never cleared out, nor expired. Larger test suites could potentially log huge amounts of data resulting in runaway memory usage. To work around this, we recommend you batch your test suite into smaller groups.

This was done to persist important data (such as error logs) across multiple page loads. Clearing this cache on each page load (unless a relevant option is set) would be more in-line with other Selenium/chromedriver behavior, but has not yet been implemented.

### URL Blocking

This does not currently work at all. The straightforward way to do this via the DevTools protocol just causes Chrome to hang indefinitely whenever the browser makes a matching request, which is worse than useless in this context.

To fix this, we'll need to implement fairly robust request interception/modification, which has proven difficult and error-prone.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joinhandshake/scree. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Scree project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/joinhandshake/scree/blob/master/CODE_OF_CONDUCT.md).
