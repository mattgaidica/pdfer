require File.expand_path('../app', __FILE__)
require 'sinatra/activerecord/rake'

namespace :server do
  desc "restart the production server"
  task :restart do
    puts `sudo /etc/init.d/apache2 restart`
  end
end

namespace :db do
  desc "Retrieves the current schema version number"
  task :version do
    puts "Current version: #{ActiveRecord::Migrator.current_version}"
  end

  desc 'Reset the database'
  task :reset do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    if File.exists?(File.join(File.dirname(__FILE__), "db/schema.rb"))
      Rake::Task['db:schema:load'].invoke
    end
    #ActiveRecord::Migrator.down('db/migrate')
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  namespace :schema do
    desc 'Output the schema to db/schema.rb'
    task :dump do
      File.open('db/schema.rb', 'w') do |f|
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, f)
      end
    end

    desc "Load a schema.rb file into the database"
    task :load do
      file = "db/schema.rb"
      load(file)
    end
  end
end