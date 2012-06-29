require "sinatra"
require "sinatra/activerecord"
require "json"
require "httparty"
require "digest/md5"
require "sqlite3"

root = ::File.dirname(__FILE__)
require File.join(root, "/config/environments")

class Document < ActiveRecord::Base
  attr_accessible :original,
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

get "/" do
  "Hey there, were  in the " + settings.environment + " environment. -PDFer"
end

post "/" do
  content_type :json
  if params[:document]
    Document.create({
      :original => params[:document],
      :token => Digest::MD5.hexdigest(rand(36**8).to_s(36))[1..16],
      :complete => false
    }).to_json
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