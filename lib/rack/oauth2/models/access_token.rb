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
          scope = Utils.normalize_scope(scope) & Utils.normalize_scope(client.scope) # Only allowed scope

          attributes = {
            :code => Server.secure_random,
            :scope => scope.join(' '),
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
          scope = Utils.normalize_scope(scope) & Utils.normalize_scope(client.scope) # Only allowed scope

          token = first(:conditions => {:identity=>identity, :scope=>scope, :client_id=>client.id, :revoked=>nil})

          token ||= begin
            attributes = {
              :code => Server.secure_random,
              :identity => identity,
              :scope => scope.join(' '),
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
          all(:condition => {:identity => identity})
        end

        # Returns all access tokens for a given client, Use limit and offset
        # to return a subset of tokens, sorted by creation date.
        def self.for_client(client_id, offset = 0, limit = 100)
          all(:conditions => {:client_id => client.id}, :offset => offset, :limit => limit, :order => :created_at)
        end

        # Returns count of access tokens.
        #
        # @param [Hash] filter Count only a subset of access tokens
        # @option filter [Integer] days Only count that many days (since now)
        # @option filter [Boolean] revoked Only count revoked (true) or non-revoked (false) tokens; count all tokens if nil
        # @option filter [String, ObjectId] client_id Only tokens grant to this client
        def self.count(filter = {})
          conditions = []
          if filter[:days]
            now = Time.now
            start_time = now - (filter[:days] * 86400)

            key = filter[:revoked] ? 'revoked' : 'created_at'
            conditions = ["#{key} > ? AND #{key} <= ?", start_time, now]
          elsif filter.has_key?(:revoked)
            conditions = ["revoked " + (filter[:revoked] ? "IS NOT NULL" : "IS NULL")]
          end

          if filter.has_key?(:client_id)
            conditions.first = conditions.empty? ? "client_id = ?" : " AND client_id = ?"
            conditions << filter[:client_id]
          end

          super(:conditions => conditions)
        end

        # def self.historical(filter = {})
        #   # days = filter[:days] || 60
        #   # select = { :$gt=> { :created_at=>Time.now - 86400 * days } }
        #   # select = {}
        # 
        #   if filter.has_key?(:client_id)
        #     conditions << "client_id = ?" << filter[:client_id]
        #   end
        # 
        #   raw = Server::AccessToken.collection.group("function (token) { return { ts: Math.floor(token.created_at / 86400) } }",
        #     select, { :granted=>0 }, "function (token, state) { state.granted++ }")
        #   raw.sort { |a, b| a["ts"] - b["ts"] }
        # end

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
