module Rack
  module OAuth2
    class Server

      # Authorization request. Represents request on behalf of client to access
      # particular scope. Use this to keep state from incoming authorization
      # request to grant/deny redirect.
      class AuthRequest < ActiveRecord::Base
        belongs_to :client, :class_name => 'Rack::OAuth2::Server::Client'
        
        validates_presence_of :client_id, :scope
        before_validation :assign_code, :on => :create
        
        def assign_code
          self.code = Server.secure_random
        end

        # Create a new authorization request. This holds state, so in addition
        # to client ID and scope, we need to know the URL to redirect back to
        # and any state value to pass back in that redirect.
        def self.create(client, scope, redirect_uri, response_type, state)

          attributes = {
            :client_id => client.id,
            :scope => scope,
            :redirect_uri => (client.redirect_uri || redirect_uri),
            :response_type => response_type,
            :state => state
          }

          AuthRequest.create!(attributes)
        end
        
        

        # Grant access to the specified identity.
        def grant!(identity)
          raise ArgumentError, "Must supply a identity" unless identity
          return if revoked

          if response_type == "code" # Requested authorization code
            access_grant = AccessGrant.create(identity, client, scope, redirect_uri)
            update_attributes(:grant_code => access_grant.code, :authorized_at => Time.now)
          else # Requested access token
            access_token = AccessToken.get_token_for(identity, client, scope)
            update_attributes(:access_token => access_token.token, :authorized_at => Time.now)
          end
        end

        # Deny access.
        # this seems broken … ?
        def deny!
          # self.authorized_at = Time.now.to_i
          # self.class.collection.update({ :_id=>id }, { :$set=>{ :authorized_at=>authorized_at } })
        end

      end

    end
  end
end
