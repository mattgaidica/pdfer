require 'stanford-core-nlp'
require 'httparty'
require 'amatch'
require 'terminal-display-colors'
require 'json'
include Amatch

=begin
response = HTTParty.get "https://s3.amazonaws.com/pdfer/8cc7054e69192f941b39f9914d923c8c.txt"

if response.code == 200
  text = response.body
else
  puts 'HTTParty error, exiting.'
  exit
end
=end

puts "\e[H\e[2J"

search = %w(person organization)

file = File.open('snippetx.txt', 'rb')
raw_text = file.read.force_encoding('UTF-8')
emails = raw_text.scan(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i).uniq
#emails = ['hs75@georgetown.edu', 'matt@syllabuster.com', 'gaid3319@kettering.edu', 'holsom.g123@mit.edu', 'billo@gmail.com']
puts "emails: #{emails.inspect}"

pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :parse, :ner, :dcoref)
text = StanfordCoreNLP::Text.new(raw_text)
pipeline.annotate(text)


entities = []
text.get(:sentences).each do |sentence|
  # Syntatical dependencies
  #puts sentence.get(:basic_dependencies).to_s
  sentence.get(:tokens).each do |token|
    entity = token.get(:named_entity_tag).to_s
    if search.include? entity.downcase
      entities << {
        :entity => entity.downcase,
        :value => token.get(:value).to_s,
        :start => token.get(:character_offset_begin).to_s.to_i,
        :end => token.get(:character_offset_end).to_s.to_i
      }
    end
  end
end

def filter_by_entity entities, entity
  entities.select{|x| x.include?(:entity) && x[:entity] == entity }
end

puts "pers: #{filter_by_entity entities, 'person'}"
puts "orgs: #{filter_by_entity entities, 'organization'}"

last_pos = nil
buffer = ''
temp = []
results = {}

search.each do |query|
  filter_by_entity(entities, query).each_with_index do |entry, i|
    if last_pos.nil? #first round
      buffer << entry[:value]
    else
      # are the entries 1 character away? is that character a space?
      puts "start minus last pos: #{(entry[:start] - last_pos)}"
      puts "raw text: #{raw_text.slice(last_pos)}"
      puts "last_pos: #{last_pos}"
      if (entry[:start] - last_pos) == 1 && raw_text.slice(last_pos).eql?(' ')
        buffer << " #{entry[:value]}"
      else
        #is there a word after it?
        #is the next sequence a space and a capitalized letter?
        # -> add it to buffer as name
        temp << buffer
        buffer = entry[:value]
      end
    end
    last_pos = entry[:end]
  end
  temp << buffer
  results[:"#{query}"] = temp.uniq
  buffer = ''
  last_pos = nil
  temp = []
end

puts results.inspect


email_rankings = []
temp = {}
emails.each do |email|
  results[:person].each do |person|
    m = Levenshtein.new(email.split('@').first.downcase.scan(/[a-z]/).join(''))
    #could try averaging matches with just their initials, last name, etc.
    tests = []
    tests << m.match(person.downcase.scan(/[a-z]/).join(''))
    tests << m.match("#{person.split(' ').first.downcase[0]}#{person.split(' ').last.downcase[0]}")
    tests << m.match(person.split(' ').first.downcase)
    tests << m.match(person.split(' ').last.downcase)
    temp[person] = tests.min
  end
  email_rankings << temp.sort_by {|k,v| v}
  temp = {}
end

puts email_rankings.inspect

#results = {:person=>["Matt Gaidica", "Grant Olidapo", "Minh Nguyen", "Brad Birdsall"], :organization=>["Georgetown University", "Department of Government", "ICC"]}

#email_rankings = [[["Matt Gaidica", 0], ["Grant Olidapo", 3], ["Minh Nguyen", 3], ["Brad Birdsall", 4]], [["Brad Birdsall", 7], ["Grant Olidapo", 11], ["Matt Gaidica", 12], ["Minh Nguyen", 13]], [["Grant Olidapo", 8], ["Brad Birdsall", 9], ["Matt Gaidica", 10], ["Minh Nguyen", 10]], [["Minh Nguyen", 1], ["Matt Gaidica", 4], ["Brad Birdsall", 5], ["Grant Olidapo", 5]]]

assignments = {}
while(assignments.keys.count < [emails.count, results[:person].count].min)
  email_rankings.each_with_index do |email_ranking, i|
    next if assignments.has_value?(emails[i]) #next if email is assigned
    email_ranking.each do |person_ranking|
      next if assignments.has_key?(person_ranking[0]) #next if name is assigned
      found_lower = false
      email_rankings.each_with_index do |email_ranking_temp, j|
        next if assignments.has_value?(emails[j]) #next if email is assigned
        email_ranking_temp.each do |person_ranking_temp|
          if person_ranking_temp[0] == person_ranking[0] && person_ranking_temp[1] < person_ranking[1]
            found_lower = true
          end
        end
      end
      if found_lower == false
        assignments[person_ranking[0]] = emails[i]
        break
      end
    end
  end
end

puts "\e[H\e[2J"
puts "\t--> People + Emails".yellow
puts JSON.pretty_generate(assignments).green

puts "\n\t--> Organizations".yellow
puts JSON.pretty_generate(results[:organization]).green

puts "\n\n\n--> Computation complete.\n\n".yellow
#puts assignments.inspect
