require "docsplit"

jobs_path = "/var/www/pdfer/samples"
file = "syllabuster.html"
pdf = [file.split(".").first, ".pdf"].join

puts "converting to pdf..."    
Docsplit.extract_pdf(file)

puts "making images..."
system "mkdir images"
Docsplit.extract_images(pdf, :size => '400x', :format => [:png])
system "mkdir images/small && mv *.png images/small"
Docsplit.extract_images(pdf, :size => '1200x', :format => [:png])
system "mkdir images/large && mv *.png images/large"

puts "extracting text..."
Docsplit.extract_text(Dir[pdf], :ocr => true, :output => 'text')

puts "moving pdf into folder..."
system "mkdir pdf && mv #{pdf} pdf/#{pdf}"
