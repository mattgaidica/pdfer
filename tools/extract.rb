require "httparty"
require "terminal-display-colors"
require "json"

document = ARGV[0]

puts "\e[H\e[2J"

def newline
  puts "\n"
end

puts "--> Getting docoument #{document}".yellow
response = HTTParty.get(document)

if response.code != 200
  puts "Could not get document, site response with a #{response.code} status.".red
else
  newline
  puts "--> Looking for ISBN numbers".yellow
  isbns = response.body.scan(/(?<isbn>(\d[- ]?){9,12}([0-9xX]))/)
  sleep(2)

  newline
  puts "--> Looking for emails".yellow
  emails = response.body.scan(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i)
  sleep(2)

  newline
  if isbns.empty?
    puts "No ISBN numbers found in document.".red
  else
    puts "Found the following ISBNs: "
    isbns.each do |isbn|
      puts "\t#{isbn[0]}".green
    end
  end
  newline

  newline
  if emails.empty?
    puts "No emails found in document.".red
  else
    puts "Found the following emails: "
    emails.each do |email|
      puts "\t#{email}".green
    end
  end
  newline
end