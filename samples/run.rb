
require "docsplit"

puts "converting to pdf..."
Docsplit.extract_pdf('syllabuster.html')

puts "making images..."
system "mkdir images"
Docsplit.extract_images("syllabuster.pdf", :size => '400x', :format => [:png])
system "mkdir images/small && mv *.png images/small"
Docsplit.extract_images("syllabuster.pdf", :size => '1200x', :format => [:png])
system "mkdir images/large && mv *.png images/large"

puts "extracting text..."
Docsplit.extract_text(Dir["syllabuster.pdf"], :ocr => true, :output => 'sample.txt')
