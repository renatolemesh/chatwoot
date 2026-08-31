# Documentos de descoberta que o ChatGPT e o Claude leem antes de iniciar o
# login: RFC 9728 (recurso protegido) e RFC 8414 (servidor de autorização).
class Oauth::MetadataController < ActionController::API
  include Oauth::BaseUrl

  def protected_resource
    render json: {
      resource: "#{base_url}/mcp",
      authorization_servers: [base_url],
      scopes_supported: [Oauth::BaseUrl::SCOPE],
      bearer_methods_supported: ['header']
    }
  end

  def authorization_server
    render json: {
      issuer: base_url,
      authorization_endpoint: "#{base_url}/oauth/authorize",
      token_endpoint: "#{base_url}/oauth/token",
      registration_endpoint: "#{base_url}/oauth/register",
      response_types_supported: ['code'],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: ['S256'],
      token_endpoint_auth_methods_supported: ['none'],
      scopes_supported: [Oauth::BaseUrl::SCOPE]
    }
  end
end
