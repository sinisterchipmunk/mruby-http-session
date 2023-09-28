class HTTP::Session::Request::Get < HTTP::Session::Request
  def initialize(uri)
    super :get, uri
  end
end
