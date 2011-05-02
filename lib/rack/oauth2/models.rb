# require "mongo"
require "openssl"
require "rack/oauth2/server/errors"
require "rack/oauth2/server/utils"

module Rack
  module OAuth2
    class Server
      # class << self
      #   # unused!
      #   attr_accessor :database
      # end

      # Long, random and hexy.
      def self.secure_random
        OpenSSL::Random.random_bytes(32).unpack("H*")[0]
      end
    end
  end
end


require "rack/oauth2/models/client"
require "rack/oauth2/models/auth_request"
require "rack/oauth2/models/access_grant"
require "rack/oauth2/models/access_token"

