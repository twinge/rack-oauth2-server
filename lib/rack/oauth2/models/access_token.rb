module Rack
  module OAuth2
    class Server

      # Access token. This is what clients use to access resources.
      #
      # An access token is a unique code, associated with a client, an identity
      # and scope. It may be revoked, or expire after a certain period.
      class AccessToken < ActiveRecord::Base
        belongs_to :client, :class_name => 'Rack::OAuth2::Server::Client' # counter_cache?

        # Creates a new AccessToken for the given client and scope.
        def self.create_token_for(client, scope)
          attributes = {
            :code => Server.secure_random,
            :scope => scope,
            :client => client
          }

          create(attributes)

          # Client.collection.update({ :_id=>client.id }, { :$inc=>{ :tokens_granted=>1 } })
          # Server.new_instance self, token
        end

        # Find AccessToken from token. Does not return revoked tokens.
        def self.from_token(token) # token == code??
          first(:conditions => {:code => token, :revoked => nil})
        end

        # Get an access token (create new one if necessary).
        def self.get_token_for(identity, client, scope)
          raise ArgumentError, "Identity must be String or Integer" unless String === identity || Integer === identity

          token = where({ :identity => identity, :scope => scope, 
            :client_id => client.id, :revoked => nil }).first

          token ||= begin
            attributes = {
              :code => Server.secure_random,
              :identity => identity,
              :scope => scope,
              :client_id => client.id
            }

            create(attributes)
            # Client.collection.update({ :_id=>client.id }, { :$inc=>{ :tokens_granted=>1 } })
          end

          token
        end

        alias_attribute :token, :code

        # Find all AccessTokens for an identity.
        def self.from_identity(identity)
          where({:identity => identity})
        end

        # Returns all access tokens for a given client, Use limit and offset
        # to return a subset of tokens, sorted by creation date.
        def self.for_client(client_id, offset = 0, limit = 100)
          where(:client_id => client_id).offset(offset).limit(limit).order(:created_at)
        end

        
        def self.historical(filter = {})
          days = filter[:days] || 60
          queryString = "select UNIX_TIMESTAMP(created_at) DIV 86400 AS ts, COUNT(DATE_FORMAT(created_at, '%e')) AS granted FROM access_tokens WHERE created_at BETWEEN DATE_SUB(NOW(), INTERVAL #{days} DAY) AND NOW()"
          if filter.has_key?(:client_id)
            queryString +=" AND client_id=#{filter[:client_id]}"
          end
          queryString += " GROUP BY ts ORDER BY ts ASC"

          #Json should look like this:  (ts is number of days since Epoch), (granted is how many token were awarded that day)
          #{"data":[{"ts":15084.0,"granted":1.0},{"ts":15092.0,"granted":1.0},{"ts":15093.0,"granted":1.0},{"ts":15109.0,"granted":1.0},{"ts":15110.0,"granted":1.0}]}

          #not going to try to do this query in Active Record...
          results = Server::AccessToken.connection.select_all(queryString)
         end

        # Updates the last access timestamp.
        def access!
          today = (Time.now.to_i / 3600) * 3600
          if last_access.nil? || last_access < today
            AccessToken.update_all({:last_access=>today, :prev_access=>last_access}, {:code => code})
            reload
          end
        end

        # Revokes this access token.
        def revoke!
          revoked = Time.now
          AccessToken.update_all({:revoked=>revoked}, {:id => id})
          reload

          # Client.collection.update({ :_id=>client_id }, { :$inc=>{ :tokens_revoked=>1 } })
        end
      end

    end
  end
end
