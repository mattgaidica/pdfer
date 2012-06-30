
require "docsplit"

Docsplit.extract_pdf('sample.html')
=begin
system "mkdir images"
Docsplit.extract_images("sample.pdf", :size => '400x', :format => [:png])
system "mkdir images/small && mv *.png images/small"
Docsplit.extract_images("sample.pdf", :size => '1200x', :format => [:png])
system "mkdir images/large && mv *.png images/large"
Docsplit.extract_text(Dir["sample.pdf"], :ocr => true, :output => 'sample.txt') 
=end
