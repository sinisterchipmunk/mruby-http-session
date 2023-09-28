assert 'response #to_s where body is a string' do
  rsp = HTTP::Session::Response.new
  rsp.status_code = 200
  rsp.status_text = 'OK'
  rsp['content-type'] = 'text/plain'
  rsp.body = 'body'

  assert_equal <<-eor.lines.map(&:chomp).join("\r\n"), rsp.to_s
HTTP/1.1 200 OK
Content-length: 4
Content-type: text/plain

body
eor
end

assert 'response #to_s where body is an IO' do
  rsp = HTTP::Session::Response.new
  rsp.status_code = 200
  rsp.status_text = 'OK'
  rsp['content-type'] = 'text/plain'
  rsp.body = HTTP::Session::Stream.new('body')

  assert_equal <<-eor.lines.map(&:chomp).join("\r\n"), rsp.to_s
HTTP/1.1 200 OK
Content-type: text/plain
Transfer-encoding: chunked

body
eor
end

assert 'response #header_s where body is a string' do
  rsp = HTTP::Session::Response.new
  rsp.status_code = 200
  rsp.status_text = 'OK'
  rsp['content-type'] = 'text/plain'
  rsp.body = 'body'

  assert_equal <<-eor.lines.map(&:chomp).join("\r\n"), rsp.header_s
HTTP/1.1 200 OK
Content-length: 4
Content-type: text/plain


eor
end

assert 'response #headers_s where body is an IO' do
  rsp = HTTP::Session::Response.new
  rsp.status_code = 200
  rsp.status_text = 'OK'
  rsp['content-type'] = 'text/plain'
  rsp.body = HTTP::Session::Stream.new("body")

  assert_equal <<-eor.lines.map(&:chomp).join("\r\n"), rsp.header_s
HTTP/1.1 200 OK
Content-type: text/plain
Transfer-encoding: chunked


eor
end

assert '#chunk_s' do
  rsp = HTTP::Session::Response.new
  assert_equal "0\r\n\r\n", rsp.chunk_s("")
  assert_equal "1\r\n1\r\n", rsp.chunk_s("1")
  assert_equal "c\r\nHello world!\r\n", rsp.chunk_s("Hello world!")
end
