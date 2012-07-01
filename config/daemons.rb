require "rubygems"
require "daemons"

Daemons.run("./config/resque-task.rb")
