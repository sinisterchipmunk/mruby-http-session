assert 'can mockup responses and logging behavior works' do
  responses = []
  log = { send: '', recv: '' }
  session = HTTP::Session.new 'http://localhost'
  session.log = Proc.new { |dir, msg| log[dir] << msg }
  session.stream = HTTP::Session::Stream.new { responses.shift&.to_s }
  session.connection = HTTP::Session::OutputStream.new

  responses << HTTP::Session::Response.new(200, 'OK', headers: { 'Content-Type' => 'application/json' }, body: '{}')
  rsp = session.get('/')

  # check the parsed response data matches our mock
  assert_equal 200, rsp.status_code
  assert_equal 'OK', rsp.status_text
  assert_equal 'HTTP/1.1', rsp.protocol
  assert_equal 'application/json', rsp['content-type']
  assert_equal '{}', rsp.body.read

  expected_request = <<-end_req.lines.map(&:chomp).join("\r\n")
GET / HTTP/1.1
Accept: */*
Connection: keep-alive
Content-length: 0
Host: localhost
User-agent: ruby


end_req

  assert_equal expected_request, session.connection.read
  assert_equal expected_request, log[:send]
end

assert 'copies domain, etc but does not copy URI path into requests' do
  uri = 'http://user:pass@localhost:8123/path?query'
  session = HTTP::Session.new uri
  %w( get post put patch delete head ).each do |verb|
    begin
      session.send(verb, '/path') do |req|
        assert_equal 'http', req.scheme
        assert_equal 'user', req.username
        assert_equal 'pass', req.password
        assert_equal 'localhost', req.hostname
        assert_equal 8123, req.port
        assert_equal '/path', req.path
        assert_nil req.query_string
      end
    rescue Errno::ECONNREFUSED
      # expected behavior, no server is running
    end
  end
end
