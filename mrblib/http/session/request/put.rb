class HTTP::Session::Request::Put < HTTP::Session::Request
  def initialize(uri, body = nil)
    super :put, uri, body
  end
end
