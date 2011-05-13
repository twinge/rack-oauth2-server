require "test/setup"


# Tests the Server API
class ServerTest < Test::Unit::TestCase
  def setup
    super
  end

  context "get_auth_request" do
    setup { @request = Server::AuthRequest.create(client, client.scope, client.redirect_uri, "token", nil) }
    should "return authorization request" do
      assert_equal @request.id, Server.get_auth_request(@request.code).id
    end

    should "return nil if no request found" do
      assert !Server.get_auth_request("4ce2488e3321e87ac1000004")
    end
  end


  context "get_client" do
    should "return authorization request" do
      assert_equal client.display_name, Server.get_client(client.id).display_name
    end

    should "return nil if no client found" do
      assert !Server.get_client("4ce2488e3321e87ac1000004")
    end
  end


  context "register" do
    context "no client ID" do
      setup do
        @client = Server.register(:display_name=>"MyApp", :link=>"http://example.org", 
                                :image_url=>"http://example.org/favicon.ico",
                                :redirect_uri=>"http://example.org/oauth/callback", 
                                :scope=>"read write")
      end

      should "create new client" do
        assert_equal 2, Server::Client.count
        assert_contains Server::Client.all.map(&:id), @client.id
      end

      should "set display name" do
        assert_equal "MyApp", Server.get_client(@client.id).display_name
      end

      should "set link" do
        assert_equal "http://example.org", Server.get_client(@client.id).link
      end

      should "set image URL" do
        assert_equal "http://example.org/favicon.ico", Server.get_client(@client.id).image_url
      end

      should "set redirect URI" do
        assert_equal "http://example.org/oauth/callback", Server.get_client(@client.id).redirect_uri
      end

      should "set scope" do
        assert_equal "read write", Server.get_client(@client.id).scope
      end

      should "assign client an ID" do
        assert_not_nil @client.id
      end

      should "assign client a secret" do
        assert_match /[0-9a-f]{64}/, @client.secret
      end
    end

    context "with client ID" do

      context "no such client" do
        setup do
          @client = Server.register(:id=>"5000015", :secret=>"foobar", 
                                    :display_name=>"MyApp", :link => "http://foo.bar/")
        end

        should "create new client" do
          assert_equal 2, Server::Client.count
        end

        # should "should assign it the client identifier" do
        #  assert_equal "5000015", @client.id.to_s
        # end

        should "should assign it the client secret" do
          assert_equal "foobar", @client.secret
        end

        should "should assign it the other properties" do
          assert_equal "MyApp", @client.display_name
        end
      end

      context "existing client" do
        setup do
          @first = Server.register(:secret => "foobar", :display_name => "MyApp", 
                          :link => "http://foo.bar")
          @client = Server.register(:id => @first.id, :secret => "foobar", 
                                    :display_name => "Rock Star", :link => "http://foo.baz")
        end

        should "not create new client" do
          assert_equal 2, Server::Client.count
        end

        should "should not change the client secret" do
          assert_equal "foobar", @client.secret
        end

        should "should change all the other properties" do
          assert_equal "Rock Star", @client.display_name
        end
      end

      context "secret mismatch" do
        setup do
          @first = Server.register(:secret=>"foobar", :display_name=>"MyApp", :link => "http://foo.bar/")
        end

        should "raise error" do
          assert_raises RuntimeError do
            Server.register(:id => @first.id, :secret=>"wrong", :display_name=>"MyApp_2", :link => "http://foo.baz/")
          end
        end
      end

    end
  end

  
  context "access_grant" do
    setup do
      code = Server.access_grant("Batman", client.id, "read")
      basic_authorize client.id, client.secret
      post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>code, :redirect_uri=>client.redirect_uri
      @token = JSON.parse(last_response.body)["access_token"]
    end

    should "resolve into an access token" do
      assert Server.get_access_token(@token)
    end

    should "resolve into access token with grant identity" do
      assert_equal "Batman", Server.get_access_token(@token).identity
    end

    should "resolve into access token with grant scope" do
      assert_equal "read", Server.get_access_token(@token).scope
    end

    should "resolve into access token with grant client" do
      assert_equal client.id, Server.get_access_token(@token).client_id
    end

    context "with no scope" do
      setup { @code = Server.access_grant("Batman", client.id) }

      should "pick client scope" do
        assert_equal "read write oauth-admin", Server::AccessGrant.from_code(@code).scope
      end
    end

    context "no expiration" do
      setup do
        @code = Server.access_grant("Batman", client.id)
      end

      should "not expire in a minute" do
        Timecop.travel 60 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 200, last_response.status
        end
      end

      should "expire after 5 minutes" do
        Timecop.travel 300 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 400, last_response.status
        end
      end
    end

    context "expiration set" do
      setup do
        @code = Server.access_grant("Batman", client.id, nil, 1800)
      end

      should "not expire prematurely" do
        Timecop.travel 1750 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 200, last_response.status
        end
      end

      should "expire after specified seconds" do
        Timecop.travel 1800 do
          basic_authorize client.id, client.secret
          post "/oauth/access_token", :scope=>"read", :grant_type=>"authorization_code", :code=>@code, :redirect_uri=>client.redirect_uri
          assert_equal 400, last_response.status
        end
      end
    end

  end


  context "get_access_token" do
    setup { @token = Server.token_for("Batman", client.id, "read") }
    should "return authorization request" do
      assert_equal @token, Server.get_access_token(@token).token
    end

    should "return nil if no client found" do
      assert !Server.get_access_token("4ce2488e3321e87ac1000004")
    end

    context "with no scope" do
      setup { @token = Server.token_for("Batman", client.id) }

      should "pick client scope" do
        assert_equal "read write oauth-admin", Server::AccessToken.from_token(@token).scope
      end
    end
  end


  context "token_for" do
    setup { @token = Server.token_for("Batman", client.id, "read write") }

    should "return access token" do
      assert_match /[0-9a-f]{32}/, @token
    end

    should "associate token with client" do
      assert_equal client.id, Server.get_access_token(@token).client_id
    end

    should "associate token with identity" do
      assert_equal "Batman", Server.get_access_token(@token).identity
    end

    should "associate token with scope" do
      assert_equal "read write", Server.get_access_token(@token).scope
    end

    should "return same token for same parameters" do
      assert_equal @token, Server.token_for("Batman", client.id, "read write")
    end

    should "return different token for different identity" do
      assert @token != Server.token_for("Superman", client.id, "read write")
    end

    should "return different token for different client" do
      client = Server.register(:display_name=>"MyApp", :link => "http://foo.bar/")
      assert @token != Server.token_for("Batman", client.id, "read write")
    end

    should "return different token for different scope" do
      assert @token != Server.token_for("Batman", client.id, "read")
    end
  end


  context "list access tokens" do
    setup do
      @one = Server.token_for("Batman", client.id, "read")
      @two = Server.token_for("Superman", client.id, "read")
      @three = Server.token_for("Batman", client.id, "write")
    end

    should "return all tokens for identity" do
      assert_contains Server.list_access_tokens("Batman").map(&:token), @one
      assert_contains Server.list_access_tokens("Batman").map(&:token), @three
    end

    should "not return tokens for other identities" do
      assert !Server.list_access_tokens("Batman").map(&:token).include?(@two)
    end

  end

end
