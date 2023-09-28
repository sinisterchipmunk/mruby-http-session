class HTTP::Session::Request::Delete < HTTP::Session::Request
  def initialize(uri)
    super :delete, uri
  end
end
