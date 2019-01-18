# frozen_string_literal: true

module EnableRemoteDebugging
  def initialize(executable_path, port, driver_opts)
    super
    @debugging_port = port + 1 # This is recalculated anyway
  end

  def debugging_uri
    @debugging_uri ||= URI.parse("http://#{@host}:#{@debugging_port}")
  end

  private

  def start_process
    @debugging_port = PortProber.above(calculated_port)
    @extra_args << "--remote-debugging-port=#{@debugging_port}"
    super
  end
end

::Selenium::WebDriver::Chrome::Service.prepend EnableRemoteDebugging
