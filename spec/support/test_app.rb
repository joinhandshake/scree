require 'haml'
require 'json'
require 'sinatra/base'
require 'sinatra/json'

class TestApp < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :static, true
  set :raise_errors, true
  set :show_exceptions, false

  get '/' do
    haml <<~HAML_DOC
      %h1 Scree Test Server
      %p Hello fine tester!
      %p You have reached the scree test server. See code for endpoints.
      %h3 Ciao!
    HAML_DOC
  end

  get '/cdp-playground' do
    haml <<~HAML_DOC
      %p This page is for testing CDP commands
    HAML_DOC
  end

  get '/check-headers' do
    haml <<~HAML_DOC
      %p
        This page is for checking HTTP headers.
        Enter your custom headers, in JSON form, in the textarea below.
      %form(action='' method='post')
        %label(for='custom_headers') Custom header JSON
        %textarea#custom_headers(name='custom_headers')
        %button(name='submit') Submit
      %hr
      %h3 Current Headers
      .current-headers
        #{request.env.select { |k, _| /^[A-Z_]+$/.match?(k) }.to_json}
    HAML_DOC
  end

  post '/check-headers' do
    custom_headers =
      begin
        JSON.parse(params['custom_headers'])
      rescue JSON::ParserError
        {}
      end

    status 200
    headers custom_headers.merge(headers)
    haml <<~HAML_DOC
      .page-loaded
        Page loaded!
      .custom-headers
        #{custom_headers.to_json}
      .request-headers
        #{request.env.to_json}
    HAML_DOC
  end

  get '/console-log' do
    haml <<~HAML_DOC
      %p
        This page is for generating console log messages.
        Enter your log messages, in JSON form, in the textarea below.
      %form(action='' method='post')
        %label(for='log_messages') Custom header JSON
        %textarea#log_messages(name='log_messages')
        %button(name='submit') Submit
    HAML_DOC
  end

  post '/console-log' do
    custom_log_messages = JSON.parse(params['log_messages'])

    haml <<~HAML_DOC
      :javascript
        #{generate_log_js(custom_log_messages)}
      .page-loaded
        Page loaded!
    HAML_DOC
  end

  get '/js-playground' do
    haml <<~HAML_DOC
      %p This page is for injecting and testing JS
      %p
        Click
        %a.home-link(href='/') here
        to follow a link.
    HAML_DOC
  end

  post '/response' do
    params['response_status'].to_i
  end

  def generate_log_js(log_messages)
    log_messages.map do |type, message|
      log_statement(type, message)
    end.join("\n  ")
  end

  def log_statement(log_type, message)
    matching_types =
      %w[log info error warn trace clear assert count time timeEnd]

    unless matching_types.include? log_type
      log_type =
        case log_type
        when 'startGroup'
          'group'
        when 'startGroupCollapsed'
          'groupCollapsed'
        when 'endGroup'
          'groupEnd'
        else
          raise "Invalid log type passed: #{log_type}"
        end
    end

    <<~JS_BODY
      console.#{log_type}('#{message.gsub("'", "\\'")}');
    JS_BODY
  end
end
