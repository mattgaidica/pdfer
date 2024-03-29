require File.expand_path("../app", __FILE__)
require "sinatra/activerecord/rake"
require "resque/tasks"

task "resque:setup" do
  ENV['QUEUE'] = '*'
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"

namespace :jobs do
  desc "Delete all jobs."
  task :delete do
    puts `rm -rf jobs/*`
  end
end

namespace :queue do
  task :restart_workers do
    pids = Array.new
    
    Resque.workers.each do |worker|
      pids << worker.to_s.split(/:/).second
    end
    
    if pids.size > 0
      system("kill -QUIT #{pids.join(' ')}")
    end
    
    system("rm /var/run/god/resque-1.21.0*.pid")
  end
end

namespace :server do
  desc "re-initilize all services"
  task :init do
    puts "restarting workers..."
    Rake::Task["queue:restart_workers"].invoke

    puts "migrating database..."
    Rake::Task["db:migrate"].invoke

    puts "installing bundle..."
    puts `bundle install`

    puts "restarting apache..."
    puts `sudo /etc/init.d/apache2 restart`

    puts "complete"
  end
  namespace :restart do
    desc "restart phusion passenger on linux"
    task :passenger do
      puts `touch /var/www/pdfer/tmp/restart.txt`
    end
    desc "restart the production server"
    task :apache do
      puts `sudo /etc/init.d/apache2 restart`
    end
  end
end

namespace :db do
  desc "Retrieves the current schema version number"
  task :version do
    puts "Current version: #{ActiveRecord::Migrator.current_version}"
  end

  desc "Reset the database"
  task :reset do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    #if File.exists?(File.join(File.dirname(__FILE__), "db/schema.rb"))
     # Rake::Task["db:schema:load"].invoke
    #end
    ActiveRecord::Migrator.down("db/migrate")
    ActiveRecord::Migrator.migrate("db/migrate")
  end

  namespace :schema do
    desc "Output the schema to db/schema.rb"
    task :dump do
      File.open("db/schema.rb", "w") do |f|
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