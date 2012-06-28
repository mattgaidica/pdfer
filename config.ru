require 'rubygems'

require File.expand_path('../app', __FILE__)

set :environment, ENV['RACK_ENV']
set :run, false

run Sinatra::Application
