require "sinatra"
require "sinatra/activerecord"
require "json"
require "digest/md5"
require "sqlite3"
require "net/http"
require "resque"
require "docsplit"
require "aws/s3"
require "fileutils"

root = File.dirname(__FILE__)

configure do
  set :jobs_path, "#{root}/jobs"
  set :host, production? ? "108.166.72.138" : "localhost:8080"
  set :s3_path, "https://s3.amazonaws.com"
end

configure :development do
  set :s3_bucket, "pdfer-dev"
end

configure :test, :production do
  set :s3_bucket, "pdfer"
end

AWS::S3::Base.establish_connection!(
  :access_key_id     => "AKIAJM6UM7QJIER6VHZA",
  :secret_access_key => "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"
)

config = YAML.load(ERB.new(File.read('./config/database.yml')).result)
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection(config[settings.environment.to_s])

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

def md5
  Digest::MD5.hexdigest(rand(36**8).to_s(36))
end

def ext filename
  filename.split(".").last
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

class Storage < ActiveRecord::Base
  attr_accessible :local,
                  :remote

  def self.bucket local
    remote = "#{md5}.#{ext(local)}"
    AWS::S3::S3Object.store(remote, open(local), settings.s3_bucket, :access => :public_read)
    if AWS::S3::Service.response.success?
      self.create({:local => local, :remote => remote})
    end
  end

  def self.store_document document
    puts document.pdf_file_path
    #should probably make sure these all exist before doing anything
    #source file
    bucket(document.source_file_path)

    #pdf file
    bucket(document.pdf_file_path)

    #images
    document.small_images_file_paths.each do |file|
      bucket(file)
    end
    document.large_images_file_paths.each do |file|
      bucket(file)
    end

    #text file
    bucket(document.text_file_path)
  end
end

class Document < ActiveRecord::Base
  attr_accessor :pdf_file_path #base document from source
  attr_accessible :token,
                  :source,
                  :complete
  
  def store
    Storage.store_document self
  end

  def job_path
    "#{settings.jobs_path}/#{self.token}"
  end

  def pdf?
    self.source[-3,3] == 'pdf'
  end

  def source_file_path
    "#{job_path}/#{Processor.sanitize_filename(self.source.split("/").last)}"
  end

  def pdf_file_path
    "#{pdf_path}/#{self.token}.pdf"
  end

  def text_file_path
    "#{text_path}/#{self.token}.txt"
  end

  def pdf_path
    "#{job_path}/pdf"
  end

  def text_path
    "#{job_path}/text"
  end

  def images_path
    "#{job_path}/images"
  end

  def small_images_path
    "#{job_path}/images/small"
  end

  def small_images_file_paths
    Dir["#{small_images_path}/*"]
  end

  def large_images_path
    "#{job_path}/images/large"
  end

  def large_images_file_paths
    Dir["#{large_images_path}/*"]
  end

  def create_tree
    puts "creating folder..."
    Dir::mkdir(job_path) #unless File.exists?(job_path)

    puts "downloading source..."
    self.download

    Dir::mkdir(pdf_path)

    if pdf?
      FileUtils.cp(source_file_path, pdf_file_path)
    else
      puts "converting to pdf..."
      #consider placing pdf in the pdf_path to start
      Docsplit.extract_pdf(source_file_path, output: job_path)
      FileUtils.mv(source_file_path[0..source_file_path.rindex(".")] + "pdf", pdf_file_path)
    end

    puts "making images..."
    Dir::mkdir("#{images_path}")

    Dir::mkdir(small_images_path)
    Docsplit.extract_images(pdf_file_path, :output => small_images_path, :size => '400x', :format => [:png])

    Dir::mkdir(large_images_path)
    Docsplit.extract_images(pdf_file_path, :output => large_images_path, :size => '1200x', :format => [:png])

    puts "extracting text..."
    Docsplit.extract_text(pdf_file_path, :ocr => false, :output => "#{text_path}")

=begin not reliable at the moment
    system "touch #{job_path}/text/#{self.token}-processed.txt"
    open("#{job_path}/text/#{self.token}-processed.txt", 'w') { |f|
      f << File.open("#{job_path}/text/#{self.token}.txt").read.gsub(/(?<!\n)\n(?!\n)/, " ")
    }
    #system "mv #{job_path}/text/#{self.token}-temp.txt #{job_path}/text/#{self.token}.txt"
=end

    self.store

    self.complete = true
    self.save
  end

  def download
    uri = URI(self.source)
    #it would be smart to follow redirects
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
    results = {}
    if storage = Storage.find_by_local(self.source_file_path)
      results = results.merge({:source => "#{settings.s3_path}/#{settings.s3_bucket}/#{storage.remote}"})
    end
    if storage = Storage.find_by_local(self.pdf_file_path)
      results = results.merge({:pdf => "#{settings.s3_path}/#{settings.s3_bucket}/#{storage.remote}"})
    end
    if storage = Storage.find_by_local(self.text_file_path)
      results = results.merge({:text => "#{settings.s3_path}/#{settings.s3_bucket}/#{storage.remote}"})
    end

    small_images = []
    small_images_file_paths.each_with_index do |image, index|
      if storage = Storage.find_by_local("#{image}")
        small_images << "#{settings.s3_path}/#{settings.s3_bucket}/#{storage.remote}"
      end
    end

    large_images = []
    large_images_file_paths.each_with_index do |image, index|
      if storage = Storage.find_by_local("#{image}")
        large_images << "#{settings.s3_path}/#{settings.s3_bucket}/#{storage.remote}"
      end
    end

    images = {
      :small_images => small_images,
      :large_images => large_images
    }

    results = results.merge({:images => images})

    {:document => results}
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
    if document.complete
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
      :token => md5,
      :source => URI.encode(params[:document]),
      :complete => false
    })
    Resque.enqueue(Processor, document.id)
    #Processor.perform(document.id)
    {:token => document.token, :link => "http://#{settings.host}/doc/#{document.token}"}.to_json
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

get "/storage" do
  document = Document.new({:token => "e7af22e691a678c8985960a5ffc0cac7", :source => "https://s3.amazonaws.com/syllabi/Business_20Statistics_20Syllabus.doc", :complete => true})
  document.store
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
