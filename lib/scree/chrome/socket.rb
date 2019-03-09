require 'socket'

module Scree
  module Chrome
    class Socket
      attr_reader :url

      def initialize(url)
        uri  = URI.parse(url)
        @url = uri.to_s
        @io  = TCPSocket.new(uri.host, uri.port)
      end

      def write(data)
        @io.print data
      end

      def read
        @io.readpartial(1024)
      end
    end
  end
end
