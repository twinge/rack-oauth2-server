module Rack
  module OAuth2
    class Server

      # The access grant is a nonce, new grant created each time we need it and
      # good for redeeming one access token.
      class AccessGrant < ActiveRecord::Base
        belongs_to :client, :class_name => 'Rack::OAuth2::Server::Client'

        # Find AccessGrant from authentication code.
        def self.from_code(code)
          first(:conditions => {:code => code, :revoked => nil})
        end

        # Create a new access grant.
        def self.create(identity, client, scope, redirect_uri = nil, expires = nil)
          raise ArgumentError, "Identity must be String or Integer" unless String === identity || Integer === identity
          scope = Utils.normalize_scope(scope) & Utils.normalize_scope(client.scope) # Only allowed scope
          expires_at = Time.now.to_i + (expires || 300)

          attributes = {
            :code => Server.secure_random,
            :identity=>identity,
            :scope=>scope,
            :client_id=>client.id,
            :redirect_uri=>client.redirect_uri || redirect_uri,
            :created_at=>Time.now.to_i,
            :expires_at=>expires_at
          }

          super(attributes)
        end

        # Authorize access and return new access token.
        #
        # Access grant can only be redeemed once, but client can make multiple
        # requests to obtain it, so we need to make sure only first request is
        # successful in returning access token, futher requests raise
        # InvalidGrantError.
        def authorize!
          raise InvalidGrantError, "You can't use the same access grant twice" if self.access_token || self.revoked
          access_token = AccessToken.get_token_for(identity, client, scope)
          update_attributes(:access_token => access_token.token, :granted_at => Time.now)
          access_token
        end

        def revoke!
          update_attributes(:revoked => Time.now)
        end
      end

    end
  end
end
