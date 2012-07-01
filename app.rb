require "sinatra"
require "sinatra/activerecord"
require "json"
require "digest/md5"
require "sqlite3"
require "net/http"
require "resque"
require "docsplit"

root = File.dirname(__FILE__)
require File.join(root, "/config/environments")

configure do
  set :jobs_path, "#{root}/jobs"
  set :host, production? ? "108.166.73.138" : "localhost:8080"
end

before do
  content_type :json
end

helpers do
  def valid_document? document
    unless (document =~ /(^$)|(^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$)/ix).nil?
      true
    end
  end
end

class Processor
  attr_accessor :job_path
  @queue = :document_id

  def self.perform(document_id)
    #begin
      document = Document.find(document_id)
      document.create_tree
    #rescue
     # puts "there was an error in finding that document."
    #end
  end

  def self.sanitize_filename(filename)
    # Split the name when finding a period which is preceded by some
    # character, and is followed by some character other than a period,
    # if there is no following period that is followed by something
    # other than a period (yeah, confusing, I know)
    fn = filename.split(/(?<=.)\.(?=[^.])(?!.*\.[^.])/m)

    # We now have one or two parts (depending on whether we could find
    # a suitable period). For each of these parts, replace any unwanted
    # sequence of characters with an underscore
    fn.map! { |s| s.gsub(/[^a-z0-9\-]+/i, '_') }

    # Finally, join the parts with a period and return the result
    return fn.join '.'
  end
end

class Document < ActiveRecord::Base
  attr_accessor :job_file_path #base document from source
  attr_accessible :token,
                  :source,
                  :complete

  def job_path
    "#{settings.jobs_path}/#{self.token}"
  end

  def pdf?
    self.source[-3,3] == 'pdf'
  end

  def source_file_path
    "#{job_path}/#{Processor.sanitize_filename(self.source.split("/").last)}"
  end

  def job_file_path
    "#{job_path}/#{self.token}.pdf"
  end

  def create_tree
    puts "creating folder..."

    system "mkdir #{job_path}"

    puts "downloading source..."
    self.download

    puts "doing production stuff..."

    if pdf?
      system "cp #{source_file_path} #{job_file_path}"
    else
      puts "converting to pdf..."
      Docsplit.extract_pdf(source_file_path, output: job_path)
      system "mv #{source_file_path[0..source_file_path.rindex('.')] + 'pdf'} #{job_file_path}"
    end

    puts "making images..."
    system "mkdir #{job_path}/images"
    Docsplit.extract_images(job_file_path, :output => job_path, :size => '400x', :format => [:png])
    system "mkdir #{job_path}/images/small && mv #{job_path}/*.png #{job_path}/images/small"
    #Docsplit.extract_images(job_file_path, :output => job_path, :size => '1200x', :format => [:png])
    system "mkdir #{job_path}/images/large && mv #{job_path}/*.png #{job_path}/images/large"

    puts "extracting text..."
    Docsplit.extract_text(job_file_path, :output => "#{job_path}/text")
=begin
    system "touch #{job_path}/text/#{self.token}-processed.txt"
    open("#{job_path}/text/#{self.token}.txt", 'w') { |f|
      f << File.open("#{job_path}/text/#{self.token}-processed.txt").read.gsub(/(?<!\n)\n(?!\n)/, " ")
    }
=end
    #system "mv #{job_path}/text/#{self.token}-temp.txt #{job_path}/text/#{self.token}.txt"

    puts "moving pdf into folder..."
    system "mkdir #{job_path}/pdf && mv #{job_file_path} #{job_path}/pdf/#{self.token}.pdf"

    self.complete = true
    self.save
  end

  def download
    uri = URI(self.source)

    if uri.scheme.eql? "https"
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          open source_file_path, 'w' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end
    else
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          open source_file_path, 'w' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end
    end
  end

  def format_results
    results = {
      :original => self.original,
      :pdf => self.pdf,
      :text => self.text,
      :images => {
        :small => Image.where(:document_id => self.id, :size => "small").map{|m| m[:image][:image]},
        :large => Image.where(:document_id => self.id, :size => "large").map{|m| m[:image][:image]}
      }
    }
  end
end

def json_status(code, reason)
  status code
  {:response => 
    {:status => code, :reason => reason}
  }.to_json
end

get "/" do
  {:welcome => "Getting Sylly with PDFer.", :environment => settings.environment}.to_json
end

get "/doc/:token" do
  if document = Document.find_by_token(params[:token])
    if !document.complete
      document.format_results.to_json
    else
      json_status 204, "Document still processing."
    end
  else
    json_status 404, "Not found."
  end
end

post "/do" do
  #do more validation on document, does it even exist?
  if params[:document] && valid_document?(params[:document])
    document = Document.create({
      :token => Digest::MD5.hexdigest(rand(36**8).to_s(36)),
      :source => params[:document],
      :complete => false
    })
    #Resque.enqueue(Processor, document.id)
    Processor.perform(document.id)
   # {:token => document.token, :link => "http://#{settings.host}/doc/#{document.token}"}.to_json
  else
    json_status 400, "Please provide a valid document."
  end
end

get "/images" do
  Image.find(:all).to_json
end

get "/documents" do
  Document.find(:all).to_json
end

# catch-alls
get "*" do
  status 404
end

post "*" do
  status 404
end

put "*" do
  status 404
end

delete "*" do
  status 404
end

not_found do
  json_status 404, "Not found"
end

error do
  json_status 500, env['sinatra.error'].message
end
