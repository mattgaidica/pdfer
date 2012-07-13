require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'sqlite3'
require 'resque'
require 'aws/s3'

class Pdfer < Sinatra::Application
  configure do
    set :jobs_path, "#{File.dirname(__FILE__)}/jobs"
    set :host, production? ? '108.166.72.138' : 'localhost:7777'
    set :access_key_id, 'AKIAJM6UM7QJIER6VHZA'
    set :secret_access_key, '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'
    set :s3_path, 'https://s3.amazonaws.com'
  end

  configure :development do
    set :s3_bucket, 'pdfer-dev'
  end

  configure :test, :production do
    set :s3_bucket, 'pdfer'
  end

  config = YAML.load(ERB.new(File.read('./config/database.yml')).result)
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.establish_connection(config[settings.environment.to_s])

  before do
    content_type :json
  end
end

require_relative 'application/helpers/init'
require_relative 'application/models/init'
require_relative 'application/routes/init'
require_relative 'application/lib/init'