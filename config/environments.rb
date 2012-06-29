RACK_ENV = ENV['RACK_ENV'] || 'development' unless defined? RACK_ENV

config = YAML.load(ERB.new(File.read('./config/database.yml')).result)
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(config[settings.environment.to_s])
