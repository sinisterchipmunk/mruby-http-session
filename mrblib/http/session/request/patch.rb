class HTTP::Session::Request::Patch < HTTP::Session::Request
  def initialize(uri, body = nil)
    super :patch, uri, body
  end
end
