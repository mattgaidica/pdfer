require 'httparty'

class Pdfer < Sinatra::Application

  get "/docs" do
    Document.find(:all).to_json
  end

  post "/docs" do
    if params[:document] && Document.valid?(params[:document])
      document = Document.create({
        :token => Digest::MD5.hexdigest(rand(36**8).to_s(36)),
        :source => params[:document],
        :complete => false
      })
      Processor.perform(document.id)
      begin
        
        #Resque.enqueue(Processor, document.id)
        {
          :token => document.token, 
          :link => "http://#{settings.host}/doc/#{document.token}"
        }.to_json
      rescue
        document.destroy
        json_status 400, "Unable to process job."
      end
    else
      json_status 400, "Please provide a valid document."
    end
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

  get "/doc/:token/view" do
    content_type 'text/html', :charset => 'utf-8'
    if @document = Document.find_by_token(params[:token])
      if @document.complete
        if pdf_storage = Storage.find_by_local(@document.pdf_file_path)
          @pdf_location = "#{settings.s3_path}/#{settings.s3_bucket}/#{pdf_storage.remote}"
          if text_storage = Storage.find_by_local(@document.text_file_path)
            response = HTTParty.get("#{settings.s3_path}/#{settings.s3_bucket}/#{text_storage.remote}")
            if response.code == 200
              extractor = Extractor.new(response.body)
              @extracted = extractor.all
            end
          end
          erb :show
        else
          "Unable to locate document."
        end
      else
        "This document is still processing."
      end
    else
      "Document not found."
    end
  end

end