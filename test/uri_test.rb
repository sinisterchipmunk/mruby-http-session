assert 'URI parses URLs correctly' do
  assert_raise(HTTP::Session::URI::ParserError) { HTTP::Session::URI.new(nil) }
  assert_raise(HTTP::Session::URI::ParserError) { HTTP::Session::URI.new('bad') }
  assert_raise(HTTP::Session::URI::ParserError) { HTTP::Session::URI.new('https') }
  assert_raise(HTTP::Session::URI::ParserError) { HTTP::Session::URI.new('http://') }

  uri = HTTP::Session::URI.new('http://www.google.com')
  assert_nil uri.username
  assert_nil uri.password
  assert_equal 'www.google.com', uri.hostname
  assert_equal false, uri.ssl?
  assert_equal 'http', uri.scheme
  assert_equal '/', uri.path
  assert_equal 80, uri.port
  assert_equal nil, uri.query_string
  assert_equal 'http://www.google.com/', uri.to_s

  uri = HTTP::Session::URI.new('https://www.yahoo.com/whatever')
  assert_nil uri.username
  assert_nil uri.password
  assert_equal 'www.yahoo.com', uri.hostname
  assert_equal true, uri.ssl?
  assert_equal 'https', uri.scheme
  assert_equal '/whatever', uri.path
  assert_equal 443, uri.port
  assert_equal nil, uri.query_string
  assert_equal 'https://www.yahoo.com/whatever', uri.to_s

  uri = HTTP::Session::URI.new('https://www.google.com:8080/whatever')
  assert_nil uri.username
  assert_nil uri.password
  assert_equal 'www.google.com', uri.hostname
  assert_equal true, uri.ssl?
  assert_equal 'https', uri.scheme
  assert_equal '/whatever', uri.path
  assert_equal 8080, uri.port
  assert_equal nil, uri.query_string
  assert_equal 'https://www.google.com:8080/whatever', uri.to_s

  uri = HTTP::Session::URI.new('http://user:pass@www.google.com:8080/whatever?querystring')
  assert_equal 'user', uri.username
  assert_equal 'pass', uri.password
  assert_equal 'www.google.com', uri.hostname
  assert_equal false, uri.ssl?
  assert_equal 'http', uri.scheme
  assert_equal '/whatever', uri.path
  assert_equal 8080, uri.port
  assert_equal 'querystring', uri.query_string
  assert_equal 'http://user:pass@www.google.com:8080/whatever?querystring',
               uri.to_s
end
