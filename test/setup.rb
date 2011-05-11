require "bundler"
Bundler.setup
require "test/unit"
require "rack/test"
require "shoulda"
require "timecop"
require "ap"
require "json"
require "logger"
$: << File.dirname(__FILE__) + "/../lib"
$: << File.expand_path(File.dirname(__FILE__) + "/..")
require 'sqlite3'
require "active_record"
require "rack/oauth2/server"
require "rack/oauth2/server/admin"
require "rack/oauth2/models"



ENV["RACK_ENV"] = "test"
DATABASE = SQLite3::Database.new("test.db")
# get active record set up
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => "test.db")

FRAMEWORK = ENV["FRAMEWORK"] || "sinatra"


$logger = Logger.new("test.log")
$logger.level = Logger::DEBUG
Rack::OAuth2::Server::Admin.configure do |config|
  config.set :logger, $logger
  config.set :logging, true
  config.set :raise_errors, true
  config.set :dump_errors, true
  config.oauth.logger = $logger
end


case FRAMEWORK
when "sinatra", nil

  #require "sinatra/base"
  puts "Testing with Sinatra #{Sinatra::VERSION}"
  require File.dirname(__FILE__) + "/sinatra/my_app"
  
  class Test::Unit::TestCase
    def app
      Rack::Builder.new do
        map("/oauth/admin") { run Server::Admin }
        map("/") { run MyApp }
      end
    end

    def config
      MyApp.oauth
    end
  end

when "rails"

  RAILS_ENV = "test"
  RAILS_ROOT = File.dirname(__FILE__) + "/rails3"
  begin
    require "rails"
  rescue LoadError
  end

  if defined?(Rails::Railtie)
    # Rails 3.x
    require "rack/oauth2/server/railtie"
    require File.dirname(__FILE__) + "/rails3/config/environment"
    puts "Testing with Rails #{Rails.version}"
    
    class Test::Unit::TestCase
      def app
        ::Rails.application
      end

      def config
        ::Rails.configuration.oauth
      end
    end

  else
    # Rails 2.x
    RAILS_ROOT = File.dirname(__FILE__) + "/rails2"
    require "initializer"
    require "action_controller"
    require File.dirname(__FILE__) + "/rails2/config/environment"
    puts "Testing with Rails #{Rails.version}"
  
    class Test::Unit::TestCase
      def app
        ActionController::Dispatcher.new
      end

      def config
        ::Rails.configuration.oauth
      end
    end
  end

else
  puts "Unknown framework #{FRAMEWORK}"
  exit -1
end


class Test::Unit::TestCase
  include Rack::Test::Methods
  include Rack::OAuth2

  def setup
    if !Server::Client.table_exists?
      ActiveRecord::Base.connection.create_table(:clients) do |t|
        t.string :code
        t.string :secret
        t.string :display_name
        t.string :link
        t.string :image_url
        t.string :redirect_uri
        t.string :scope
        t.string :notes
        t.datetime :created_at
        t.datetime :updated_at
        t.datetime :revoked
      end
    end
    if !Server::AuthRequest.table_exists?
      ActiveRecord::Base.connection.create_table(:auth_requests) do |t|
        t.string :code
        t.string :client_id
        t.string :scope
        t.string :redirect_uri
        t.string :state
        t.string :response_type
        t.string :grant_code
        t.string :access_token
        t.datetime :created_at
        t.datetime :updated_at
        t.datetime :authorized_at
        t.datetime :revoked
      end
    end
    if !Server::AccessGrant.table_exists?
      ActiveRecord::Base.connection.create_table(:access_grants) do |t|
        t.string :code
        t.string :access_token
        t.string :identity
        t.string :client_id
        t.string :scope
        t.datetime :granted_at
        t.datetime :created_at
        t.datetime :updated_at
        t.string :redirect_uri
        t.datetime :expires_at
        t.datetime :revoked
        t.datetime :last_access
        t.datetime :prev_access
      end
    end
    if !Server::AccessToken.table_exists?
      ActiveRecord::Base.connection.create_table(:access_tokens) do |t|
        t.string :code
        t.string :identity
        t.string :client_id
        t.string :redirect_uri
        t.string :scope
        t.datetime :created_at
        t.datetime :updated_at
        t.datetime :granted_at
        t.datetime :expires_at
        t.string :access_token
        t.datetime :revoked
      end
    end
    Server::Admin.scope = %{read write}
    @client = Server.register(
      :display_name => "UberClient", 
      :redirect_uri => "http://uberclient.dot/callback", 
      :link => "http://example.com/", 
      :scope => %w{read write oauth-admin})
  end

  attr_reader :client, :end_user

  def teardown
    ActiveRecord::Base.connection.drop_table(:clients)
    ActiveRecord::Base.connection.drop_table(:auth_requests)
    ActiveRecord::Base.connection.drop_table(:access_grants)
    ActiveRecord::Base.connection.drop_table(:access_tokens)
  end
end
