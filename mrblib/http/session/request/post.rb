class HTTP::Session::Request::Post < HTTP::Session::Request
  def initialize(uri, body = nil)
    super :post, uri, body
  end
end
