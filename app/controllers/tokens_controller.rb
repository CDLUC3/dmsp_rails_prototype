# frozen_string_literal: true

class TokensController < ApplicationController
  include ExternalParameters

  # GET /token?code[AuthCode]
  def exchange_code_for_token
    puts event['queryStringParameters']

    opts = _options(code: event.fetch('queryStringParameters', {})['code'])
    resp = HTTParty.send(:post, ENV['AUTH_ENDPOINT'], opts)
    return { statusCode: 500, body: "Unable to acquire token" } if resp.body.nil? || resp.body.empty?

    { statusCode: 200, body: resp.body.to_json, headers: _response_headers }
  end

  private

  def _options
    callback_uri = ENV['CALLBACK_ENDPOINT']
    client_id = _get_ssm_val(key: "#{ENV['SSM_PATH']}DmspClientId")
    client_secret = _get_ssm_val(key: "#{ENV['SSM_PATH']}DmspClientSecret")

    ret = {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': "Basic #{Base64.encode64("#{client_id}:#{client_secret}").gsub(/\n/, '')}",
        'User-Agent': "Cognito auth tester"
      },
      body: "grant_type=authorization_code&code=#{code}&redirect_uri=#{callback_uri}&client_id=#{client_id}",
      follow_redirects: true,
      limit: 6
    }
    ret[:debug_output] = $stdout if ENV['LOG_LEVEL'] == 'debug'
    ret
  end
end
