require "httparty"
require "json"
require "terminal-display-colors"

def newline
  puts "\n"
end

def stop_pdfer message=""
  newline
  puts "--> #{message}".yellow
  newline
  exit
end

def print_and_flush(str)
  print str
  $stdout.flush
end

puts "\e[H\e[2J"
document = ARGV[0]
if !ARGV.nil? && ARGV[1].eql?("production")
  host = "http://108.166.72.138"
else
  host = "http://localhost:8080"
end

puts "--> Using #{host} as host".yellow
puts "--> Sending #{document} to PDFer".yellow
newline

do_response = HTTParty.post("#{host}/do", {:body => {:document => document}})

if do_response.code == 200
  puts "\ttoken: " + "#{do_response["token"]}".blue
  puts "\tlink: " + "#{do_response["link"]}".blue

  newline

  processing = true
  puts "--> Doc #{do_response["token"]} is processing".yellow
  puts "\t"
  while(processing)
    doc_response = HTTParty.get("#{host}/doc/#{do_response["token"]}")
    if doc_response.code == 200
      processing = false
    elsif doc_response.code == 204
      print_and_flush "."
      sleep 1
    else
      stop_pdfer "PDFer responded with a #{doc_response.code} status from '/doc/#{do_response["token"]}'.".red
    end
  end

  newline
  newline
  puts JSON.pretty_generate(JSON.parse(doc_response.body)).green
  stop_pdfer "We are done here"
else
  puts "PDFer responded with a #{do_response.code} status from '/do'.".red
  stop_pder
end