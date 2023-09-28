assert 'HTTP::Session::Request' do
  req = HTTP::Session::Request.new(:get, 'http://www.google.com/path?query=1')
  assert_equal '*/*', req['accept']
  assert_equal 'ruby', req['uSeR-AgEnT'] # headers case insensitive
  assert_equal <<-end_req.lines.map(&:chomp).join("\r\n"), req.to_s
GET /path?query=1 HTTP/1.1
Accept: */*
Content-length: 0
Host: www.google.com
User-agent: ruby


end_req

  # I can add my own headers?
  req['cache-control'] = 'no-cache'
  assert_equal <<-end_req.lines.map(&:chomp).join("\r\n"), req.to_s
GET /path?query=1 HTTP/1.1
Accept: */*
Cache-control: no-cache
Content-length: 0
Host: www.google.com
User-agent: ruby


end_req

  # I can change the body?
  req.body = 'body'
  assert_equal <<-end_req.lines.map(&:chomp).join("\r\n"), req.to_s
GET /path?query=1 HTTP/1.1
Accept: */*
Cache-control: no-cache
Content-length: 4
Host: www.google.com
User-agent: ruby

body
end_req
end

assert 'HTTP::Session::Request::Get' do
  req = HTTP::Session::Request::Get.new('http://www.google.com/path?query=1')
  assert_equal :get, req.verb
  assert_nil req.body
end

assert 'HTTP::Session::Request::Post' do
  req = HTTP::Session::Request::Post.new('http://www.google.com/path?query=1')
  assert_equal :post, req.verb
  assert_nil req.body

  req = HTTP::Session::Request::Post.new('http://www.google.com/path?query=1', 'body')
  assert_equal :post, req.verb
  assert_equal 'body', req.body
end

assert 'HTTP::Session::Request::Patch' do
  req = HTTP::Session::Request::Patch.new('http://www.google.com/path?query=1', 'body')
  assert_equal :patch, req.verb
  assert_equal 'body', req.body
end

assert 'HTTP::Session::Request::Put' do
  req = HTTP::Session::Request::Put.new('http://www.google.com/path?query=1', 'body')
  assert_equal :put, req.verb
  assert_equal 'body', req.body
end

assert 'HTTP::Session::Request::Delete' do
  req = HTTP::Session::Request::Delete.new('http://www.google.com/path?query=1')
  assert_equal :delete, req.verb
end
