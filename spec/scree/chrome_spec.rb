require 'spec_helper'
require 'scree/chrome'

describe Chrome do
  describe '#client_for' do
    it 'creates a new Client for given host/port' do
      host = 'example.com'
      port = 443

      allow(Chrome::Client).to receive(:new).with(host, port)
      described_class.client(host, port)
      expect(Chrome::Client).to have_received(:new).with(host, port)
    end
  end
end
