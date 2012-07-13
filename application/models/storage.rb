require 'digest/md5'
require 'aws/s3'

class Storage < ActiveRecord::Base
  attr_accessible :local,
                  :remote
  attr_accessor :access_key_id, :secret_access_key, :s3_bucket, :s3_path

  def access_key_id
    Pdfer.settings.access_key_id
  end

  def secret_access_key
    Pdfer.settings.secret_access_key
  end

  def s3_bucket
    Pdfer.settings.s3_bucket
  end

  def s3_path
    Pdfer.settings.s3_path
  end

  def self.ext filename
    filename.split(".").last
  end

  def establish_connection
    AWS::S3::Base.establish_connection!(
      :access_key_id     => access_key_id,
      :secret_access_key => secret_access_key
    )
  end

  def put_in_bucket local
    remote = "#{Digest::MD5.hexdigest(rand(36**8).to_s(36))}.#{self.class.ext(local)}"
    
    establish_connection
    AWS::S3::S3Object.store(remote, open(local), s3_bucket, :access => :public_read)
    if AWS::S3::Service.response.success?
      self.class.create({
        :local => local, 
        :remote => remote
      })
    end
  end

  def store_document document
    # should probably make sure these all exist before doing anything
    # source file
    put_in_bucket(document.source_file_path)
    # pdf file
    put_in_bucket(document.pdf_file_path)
    # images
    document.small_images_file_paths.each do |file|
      put_in_bucket(file)
    end
    document.large_images_file_paths.each do |file|
      put_in_bucket(file)
    end
    # text file
    put_in_bucket(document.text_file_path)
  end
end