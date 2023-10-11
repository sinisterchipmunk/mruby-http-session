assert 'parse client request with content-length in one big blob' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Content-length: 2

{}extra data that shouldn't be parsed due to content-length
end_rsp
  stream = HTTP::Session::Stream.new { |c| data ? data[0, c].tap { data = data[c..-1] } : nil }
  request = HTTP::Session::Request::Parser.new(stream).request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal '{}', request.body.read(request['content-length'].to_i)
  assert_equal 'application/json', request['content-type']
  assert_equal "extra data that shouldn't be parsed due to content-length",
               stream.read
end

assert 'parse client request with content-length one byte at a time' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Content-length: 2

{}extra data that shouldn't be parsed due to content-length
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  request = HTTP::Session::Request::Parser.new(stream).request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal '2', request['content-length']
  assert_equal '{}', request.body.read
  assert_equal 'application/json', request['content-type']
  assert_equal "extra data that shouldn't be parsed due to content-length",
               stream.read
end

assert 'parse client request with neither content length nor chunked encoding' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json

{}
extra data that should still be parsed
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { x = chars.next rescue nil }
  request = HTTP::Session::Request::Parser.new(stream).request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal "{}\r\nextra data that should still be parsed", request.body.read
  assert_equal 'application/json', request['content-type']
  assert_nil stream.read
end

assert 'parse client request with chunked encoding, received one byte at a time' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Transfer-encoding: chunked

7
chunk 1
8
 chunk 2
0

unparsed data following zero chunk
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  request = HTTP::Session::Request::Parser.new(stream).request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal "chunk 1 chunk 2", request.body.read
  assert_equal 'application/json', request['content-type']
  assert_equal 'unparsed data following zero chunk', stream.read
end

assert 'parse chunked data for 2 separate responses' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Transfer-encoding: chunked

7
chunk 1
8
 chunk 2
0

GET /path HTTP/1.1
Content-type: application/json
Transfer-encoding: chunked

7
chunk 1
8
 chunk 2
0

unparsed data following zero chunk
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  request1 = HTTP::Session::Request::Parser.new(stream).request
  body1 = request1.body.read
  request2 = HTTP::Session::Request::Parser.new(stream).request
  body2 = request2.body.read
  assert_equal :get, request1.verb
  assert_equal '/path', request1.path
  assert_equal 'HTTP/1.1', request1.protocol
  assert_equal "chunk 1 chunk 2", body1
  assert_equal 'application/json', request1['content-type']
  assert_equal :get, request2.verb
  assert_equal '/path', request2.path
  assert_equal 'HTTP/1.1', request2.protocol
  assert_equal "chunk 1 chunk 2", body2
  assert_equal 'application/json', request2['content-type']
  assert_equal 'unparsed data following zero chunk', stream.read
end

assert 'polling-based parser' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Content-length: 2

{}
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  parser = HTTP::Session::Request::Parser.new(stream)
  assert_false parser.ready?, 'request has not been parsed, should not be ready'
  parser.parse until parser.ready?
  request = parser.request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal '{}', request.body.read
  assert_equal 'application/json', request['content-type']
end

assert 'polling-based parser parses everything in 1 call if the data is available' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
GET /path HTTP/1.1
Content-type: application/json
Content-length: 2

{}
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new(data) { nil }
  parser = HTTP::Session::Request::Parser.new(stream)
  assert_false parser.ready?, 'request has not been parsed, should not be ready'
  parser.parse
  assert_true parser.ready?, 'all data was available, should be ready'
  request = parser.request
  assert_equal :get, request.verb
  assert_equal '/path', request.path
  assert_equal 'HTTP/1.1', request.protocol
  assert_equal '{}', request.body.read
  assert_equal 'application/json', request['content-type']
end
