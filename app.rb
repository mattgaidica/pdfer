require "sinatra"
require "sinatra/activerecord"
require "json"
require "httparty"
require "digest/md5"
require "sqlite3"

root = ::File.dirname(__FILE__)
require File.join(root, "/config/environments")

host = production? ? "23.21.187.103" : "localhost"

class Document < ActiveRecord::Base
  attr_accessible :token,
                  :original,
                  :pdf,
                  :text,
                  :complete
  has_many :images
end

class Image < ActiveRecord::Base
  attr_accessible :size,
                  :image
  belongs_to :document
end

def json_status(code, reason)
  status code
  {:response => 
    {
      :status => code,
      :reason => reason
    }
  }.to_json
end

get "/" do
  "Hey there, were  in the " + settings.environment + " environment. -PDFer"
end

get "/:token" do
  document = Document.find_by_token(params[:token]).to_json
end

post "/" do
  content_type :json
  if params[:document]
    document = Document.create({
      :original => params[:document],
      :token => Digest::MD5.hexdigest(rand(36**8).to_s(36))[1..16],
      :complete => false
    })
    {:token => document.token, :status => "http://#{host}/#{document.token}"}.to_json
  end
end

get "/images" do
  content_type :json
  Image.find(:all).to_json
end

get "/documents" do
  content_type :json
  Document.find(:all).to_json
end