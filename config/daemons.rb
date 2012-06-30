require "rubygems"
require "daemons"

Daemons.run("resque-task.rb")
