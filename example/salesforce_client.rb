module Example
  class SalesforceClient
    attr_reader :metadata

    def initialize
      @host = ENV.fetch('SF_HOST')
      @auth_url = @host + ENV.fetch('SF_AUTH_ENDPOINT')
    end

    def auth
      response = Faraday.post(@auth_url) do |req|
        req.body = { grant_type: 'client_credentials', client_id: ENV.fetch('SF_CLIENT_ID'), client_secret: ENV.fetch('SF_CLIENT_SECRET') }
      end

      body = JSON.parse(response.body)

      @metadata = {
        'accesstoken' => body.fetch('access_token'),
        'instanceurl' => body.fetch('instance_url'),
        'tenantid' => ENV.fetch('TENANT_ID'),
      }
    end
  end
end