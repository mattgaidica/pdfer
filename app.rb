require "sinatra"
require "sinatra/activerecord"
require "json"
require "httparty"
require "digest/md5"
require "sqlite3"

root = ::File.dirname(__FILE__)
require File.join(root, "/config/environments")

host = production? ? "23.21.187.103" : "localhost:8080"

before do
  content_type :json
end

class Document < ActiveRecord::Base
  attr_accessible :token,
                  :original,
                  :pdf,
                  :text,
                  :complete
  has_many :images

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

get "/:token" do
  if document = Document.find_by_token(params[:token])
    if !document.complete
      document.format_results.to_json
    else
      json_status 400, "Document still processing."
    end
  else
    json_status 404, "Not found."
  end
end

post "/" do
  if params[:document]
    document = Document.create({
      :original => params[:document],
      :token => Digest::MD5.hexdigest(rand(36**8).to_s(36)),
      :complete => false
    })
    {:token => document.token, :status => "http://#{host}/#{document.token}"}.to_json
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