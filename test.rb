 images = [{:image=>{:size=>"small", :image=>"http://"}}, {:image=>{:size=>"small", :image=>"goog.com"}}, {:image=>{:size=>"large", :image=>"sylly.co"}}, {:image=>{:size=>"large", :image=>"boom.yea"}}] 

small_images = images.map{|image| image[:image][:image]}
puts small_images.inspect