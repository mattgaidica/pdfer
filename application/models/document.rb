require 'docsplit'
require 'net/http'
require 'fileutils'

class Document < ActiveRecord::Base
  attr_accessor :pdf_file_path #base document from source
  attr_accessible :token,
                  :source,
                  :complete

  def job_path
    "#{Pdfer.settings.jobs_path}/#{self.token}"
  end

  def self.valid? document
    whitelist = %w(doc docx pdf html txt png jpg jpeg)
    if document =~ /(^$)|(^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$)/ix && whitelist.include?(document.split('.').last)
      true
    end
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
      Docsplit.extract_pdf(source_file_path, :output => job_path)
      FileUtils.mv(source_file_path[0..source_file_path.rindex(".")] + "pdf", pdf_file_path)
    end

    puts "making images..."
    Dir::mkdir("#{images_path}")

    Dir::mkdir(small_images_path)
    Docsplit.extract_images(pdf_file_path, :output => small_images_path, :size => '400x', :format => [:png])

    Dir::mkdir(large_images_path)
    Docsplit.extract_images(pdf_file_path, :output => large_images_path, :size => '1200x', :format => [:png])

    puts "extracting text..."
    Docsplit.extract_text(pdf_file_path, :ocr => false, :output => text_path)

    text_file_line_count = %x{wc -l #{text_file_path}}.split.first.to_i
    if text_file_line_count == 0
      Docsplit.extract_text(pdf_file_path, :ocr => true, :output => "#{text_path}")
    end

    storage = Storage.new
    storage.store_document(self)
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
      results = results.merge({:source => "#{Pdfer.settings.s3_path}/#{Pdfer.settings.s3_bucket}/#{storage.remote}"})
    end
    if storage = Storage.find_by_local(self.pdf_file_path)
      results = results.merge({:pdf => "#{Pdfer.settings.s3_path}/#{Pdfer.settings.s3_bucket}/#{storage.remote}"})
    end
    if storage = Storage.find_by_local(self.text_file_path)
      results = results.merge({:text => "#{Pdfer.settings.s3_path}/#{Pdfer.settings.s3_bucket}/#{storage.remote}"})
    end

    small_images = []
    small_images_file_paths.each_with_index do |image, index|
      if storage = Storage.find_by_local("#{image}")
        small_images << "#{Pdfer.settings.s3_path}/#{Pdfer.settings.s3_bucket}/#{storage.remote}"
      end
    end

    large_images = []
    large_images_file_paths.each_with_index do |image, index|
      if storage = Storage.find_by_local("#{image}")
        large_images << "#{Pdfer.settings.s3_path}/#{Pdfer.settings.s3_bucket}/#{storage.remote}"
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