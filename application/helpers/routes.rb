module Routes
  def json_status(code, reason)
    status code
    {:response => 
      {
        :status => code,
        :reason => reason
      }
    }.to_json
  end
end