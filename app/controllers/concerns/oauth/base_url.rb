# A URL pública da instalação, usada nos documentos de descoberta e nos
# redirecionamentos. Atrás do nginx o `request.base_url` pode vir errado, então
# o FRONTEND_URL tem precedência.
module Oauth::BaseUrl
  extend ActiveSupport::Concern

  SCOPE = 'mcp'.freeze

  private

  def base_url
    ENV.fetch('FRONTEND_URL', nil).presence&.chomp('/') || request.base_url
  end
end
