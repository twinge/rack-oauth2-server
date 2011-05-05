module Rack
  module OAuth2
    class Server

      class Client < ActiveRecord::Base
        has_many :auth_requests, :dependent => :destroy
        has_many :access_grants, :dependent => :destroy
        has_many :access_tokens, :dependent => :destroy

        validates_presence_of :display_name
        validates_presence_of :link
        validates_presence_of :code
        validates_presence_of :secret

        validates_uniqueness_of :display_name
        validates_uniqueness_of :link
        validates_uniqueness_of :code
        validates_uniqueness_of :secret

        before_validation_on_create :assign_code_and_secret

        # Create a new client. Client provides the following properties:
        # # :display_name -- Name to show (e.g. UberClient)
        # # :link -- Link to client Web site (e.g. http://uberclient.dot)
        # # :image_url -- URL of image to show alongside display name
        # # :redirect_uri -- Registered redirect URI.
        # # :scope -- List of names the client is allowed to request.
        # # :notes -- Free form text.
        # 
        # This method does not validate any of these fields, in fact, you're
        # not required to set them, use them, or use them as suggested. Using
        # them as suggested would result in better user experience.  Don't ask
        # how we learned that.
        # def self.create(args)
        #   unless args[:redirect_uri].blank?
        #     redirect_uri = Server::Utils.parse_redirect_uri(args.delete(:redirect_uri)).to_s
        #   end
        # 
        #   scope = Server::Utils.normalize_scope(args[:scope])
        #   args.merge!({:redirect_uri => redirect_uri})
        # 
        #   if args[:id] && args[:secret]
        #     args[:code] = args.delete(:id)
        #     super(args)
        #   else
        #     args[:secret] = Server.secure_random
        #     super(args)
        #   end
        # end

        def assign_code_and_secret
          self.code = Server.secure_random[0,20]
          self.secret = Server.secure_random
        end

        def redirect_url=(url)
          self[:redirect_uri] = Server::Utils.parse_redirect_uri(url).to_s
        end

        # Lookup client by ID, display name or URL.
        def self.lookup(field)
          find_by_id(field) || find_by_code(field) || find_by_display_name(field) || find_by_link(field)
        end

        # # Counts how many access tokens were granted.
        # attr_reader :tokens_granted
        # # Counts how many access tokens were revoked.
        # attr_reader :tokens_revoked

        # Revoke all authorization requests, access grants and access tokens for
        # this client. Ward off the evil.
        def revoke!
          revoked_at = Time.now
          update_attribute(:revoked, revoked_at)
          # can we use the association here
          AuthRequest.update_all(:revoked=>revoked_at, :client_id=>id)
          AccessGrant.update_all(:revoked=>revoked_at, :client_id=>id)
          AccessToken.update_all(:revoked=>revoked_at, :client_id=>id)
        end

        # def update(args)
        #   redirect_url = Server::Utils.parse_redirect_uri(args[:redirect_uri]).to_s unless args[:redirect_uri].blank?
        #   args.merge!({
        #     :redirect_url => redirect_url,
        #     :scope => Server::Utils.normalize_scope(args.delete(:scope))
        #   })
        # 
        #   update_attributes(args)
        # end
      end
    end
  end
end
