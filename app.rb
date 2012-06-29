require "sinatra"
require "sinatra/activerecord"
require "json"
require "digest/md5"
require "sqlite3"
require "net/http"

root = ::File.dirname(__FILE__)
require File.join(root, "/config/environments")

configure do
  set :jobs_folder, "./jobs"
  set :host, production? ? "23.21.187.103" : "localhost:8080"
end

before do
  content_type :json
end

class Processor
  def self.create_job_folder token
    directory = "#{settings.jobs_folder}/#{token}"
    Dir::mkdir(directory) unless File.exists?(directory)
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
  attr_accessible :token,
                  :original,
                  :pdf,
                  :text,
                  :complete
  has_many :images

  def download_original
    uri = URI(self.original)
    filename = Processor.sanitize_filename(self.original.split("/").last)
    save_location = "#{settings.jobs_folder}/#{self.token}/#{filename}"

    if uri.scheme.eql? "https"
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new uri.request_uri
        http.request request do |response|
          open save_location, 'w' do |io|
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
          open save_location, 'w' do |io|
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

class Image < ActiveRecord::Base
  attr_accessible :size,
                  :image
  belongs_to :document
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

post "/doc" do
  if params[:document]
    document = Document.create({
      :original => params[:document],
      :token => Digest::MD5.hexdigest(rand(36**8).to_s(36)),
      :complete => false
    })
    {:token => document.token, :status => "https://#{settings.host}/doc/#{document.token}"}.to_json
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