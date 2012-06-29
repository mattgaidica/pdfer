require File.expand_path('../app', __FILE__)
require 'sinatra/activerecord/rake'

namespace :server do
  task :restart do
    puts `sudo /etc/init.d/apache2 restart`
  end
end