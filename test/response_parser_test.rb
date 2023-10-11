assert 'parse server response with content-length in one big blob' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
Content-type: application/json
Content-length: 2

{}extra data that shouldn't be parsed due to content-length
end_rsp
  stream = HTTP::Session::Stream.new { |c| data ? data[0, c].tap { data = data[c..-1] } : nil }
  response = HTTP::Session::Response::Parser.new(stream).response
  assert_equal 200, response.status
  assert_equal 'HTTP/1.1', response.protocol
  assert_equal 'OK', response.status_text
  assert_equal '{}', response.body.read(response['content-length'].to_i)
  assert_true response.body.eof?
  assert_equal 'application/json', response['content-type']
  assert_equal "extra data that shouldn't be parsed due to content-length",
               stream.read
end

assert 'parse server response with content-length one byte at a time' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
Content-type: application/json
Content-length: 2

{}extra data that shouldn't be parsed due to content-length
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  response = HTTP::Session::Response::Parser.new(stream).response
  assert_equal 'HTTP/1.1', response.protocol
  assert_equal 'OK', response.status_text
  assert_equal '2', response['content-length']
  assert_equal '{}', response.body.read
  assert_true response.body.eof?
  assert_equal 'application/json', response['content-type']
  assert_equal "extra data that shouldn't be parsed due to content-length",
               stream.read
end

assert 'parse server response with neither content length nor chunked encoding' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
Content-type: application/json

{}
extra data that should still be parsed
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { x = chars.next rescue nil }
  response = HTTP::Session::Response::Parser.new(stream).response
  assert_equal 'HTTP/1.1', response.protocol
  assert_equal 'OK', response.status_text
  assert_equal "{}\r\nextra data that should still be parsed", response.body.read
  assert_equal 'application/json', response['content-type']
  assert_nil stream.read
end

assert 'parse server response with chunked encoding, received one byte at a time' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
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
  response = HTTP::Session::Response::Parser.new(stream).response
  assert_equal 'HTTP/1.1', response.protocol
  assert_equal 'OK', response.status_text
  assert_equal "chunk 1 chunk 2", response.body.read
  assert_equal 'application/json', response['content-type']
  assert_equal 'unparsed data following zero chunk', stream.read
end

assert 'parse chunked data for 2 separate responses' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
Content-type: application/json
Transfer-encoding: chunked

7
chunk 1
8
 chunk 2
0

HTTP/1.1 404 Not Found
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
  response1 = HTTP::Session::Response::Parser.new(stream).response
  body1 = 15.times.map { response1.body.read(1) }.join
  assert_true response1.body.eof?
  response2 = HTTP::Session::Response::Parser.new(stream).response
  body2 = 15.times.map { response2.body.read(1) }.join
  assert_true response2.body.eof?
  assert_equal 'HTTP/1.1', response1.protocol
  assert_equal 'OK', response1.status_text
  assert_equal "chunk 1 chunk 2", body1
  assert_equal 'application/json', response1['content-type']
  assert_equal 'HTTP/1.1', response2.protocol
  assert_equal 'Not Found', response2.status_text
  assert_equal "chunk 1 chunk 2", body2
  assert_equal 'application/json', response2['content-type']
  assert_equal 'unparsed data following zero chunk', stream.read
end

assert 'polling-based parser' do
  data = <<-end_rsp.lines.map(&:chomp).join("\r\n")
HTTP/1.1 200 OK
Content-type: application/json
Content-length: 2

{}
end_rsp
  chars = data.each_char # enumerator
  stream = HTTP::Session::Stream.new { chars.next rescue nil }
  parser = HTTP::Session::Response::Parser.new(stream)
  assert_false parser.ready?, 'response has not been parsed, should not be ready'
  parser.parse until parser.ready?
  response = parser.response
  assert_equal 200, response.status
  assert_equal 'HTTP/1.1', response.protocol
  assert_equal 'OK', response.status_text
  assert_equal 'application/json', response['content-type']
  assert_equal '{}', response.body.read
end
