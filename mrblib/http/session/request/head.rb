class HTTP::Session::Request::Head < HTTP::Session::Request
  def initialize(uri)
    super :head, uri
  end
end
