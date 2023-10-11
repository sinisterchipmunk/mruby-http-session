module HTTP::Session
  class Session
    # The HTTP::Session::URI which describes the host that this session is
    # connected to. Note that the path and query string are ignored by Session.
    attr_reader :uri

    # The underlying TCP or SSL connection.
    attr_reader :connection

    # Options to be passed to the SSL context during its initialization.
    # Ignored if this is not an HTTPS session. Valid options include
    # :ca_chain, :client_cert, and :client_key.
    attr_accessor :ssl_options

    # One of:
    #   PolarSSL::SSL::SSL_VERIFY_REQUIRED (default)
    #   PolarSSL::SSL::SSL_VERIFY_OPTIONAL
    #   PolarSSL::SSL::SSL_VERIFY_NONE
    attr_accessor :ssl_verify

    # Timeout in seconds since the last time data was received. The connection
    # will fail after this timeout expires.
    attr_accessor :read_timeout

    # The underlying byte stream that data will be received (but not sent)
    # upon. You may want to replace this for unit testing.
    #
    # Example:
    #     session.stream = HTTP::Session::Stream.new(MOCKED_RESPONSE_DATA)
    #     rsp = session.get('/') #=> Mocked HTTP response
    #
    attr_accessor :stream

    # The underlying connection which data will be written to. You can
    # replace this for unit testing, although in doing so you'll almost
    # certainly want to check out #stream as well.
    #
    # Example:
    #     session.connection = HTTP::Session::OutputStream.new
    #     rsp = session.get('/')
    #     session.connection.read #=> reads back the request string
    #
    attr_accessor :connection

    # If set, this Proc will be invoked with all data sent and received
    # on this channel. It takes two arguments. The first is either `:send` or
    # `:recv`. The second is the string of data sent or received.
    #
    # The string will always be at least 1 byte long, but there are no other
    # guarantees about its length. It may contain only part of the payload,
    # with the remainder to come later.
    attr_accessor :log

    def initialize(url)
      @on_connection = nil
      @log = nil
      @ssl_verify = PolarSSL::SSL::SSL_VERIFY_REQUIRED
      @uri = url.kind_of?(URI) ? url : URI.new(url)
      @read_timeout = 5.0
      @ssl_options = { }
      when_blocking { |io, timeout| IO.select(io_for_select, nil, nil, timeout) }
      @stream = Stream.new { |c| receive_data(c) }
    end

    def ssl?
      @uri.ssl?
    end

    # Whenever the connection would block (wait for data), the given block
    # will be invoked. The underlying IO or SSL connection and the amount of
    # time remaining until timeout are yielded to the block.
    #
    # Example:
    #   session.when_blocking { |io, time_remaining| ... }
    #
    def when_blocking(&block)
      @when_blocking = block
    end

    # Close the connection with the host. Subsequent requests will be forced
    # to reopen the connection.
    #
    # Note: any response body streams that you have not finished reading will
    # be closed.
    def close
      connection.close
    end

    # Waits until the underlying TCP or SSL reports data is available for
    # processing. This method will not return until data is available, but
    # will invoke the block given to #when_blocking, if any. If `timeout_secs`
    # is given and has expired, this method will raise Errno::ETIMEDOUT.
    # Otherwise, it will wait forever.
    private def wait_for_data!(timeout_secs)
      timeout_at = Time.now + timeout_secs
      until bytes_available?
        @when_blocking.call(@connection, (timeout_at - Time.now).to_f)
        raise Errno::ETIMEDOUT, 'timed out' if Time.now >= timeout_at
      end
    end

    # Returns true if data is available on the underlying TCP or SSL.
    def bytes_available?
      ssl? ? connection.bytes_available > 0 : IO.select(io_for_select, nil, nil, 0)
    end

    private def io_for_select
      [ssl? ? connection.socket : connection]
    end

    def establish_connection
      socket = TCPSocket.new @uri.hostname, @uri.port
      socket._setnonblock true
      if ssl?
        entropy = PolarSSL::Entropy.new
        ctr_drbg = PolarSSL::CtrDrbg.new(entropy)
        ssl = PolarSSL::SSL.new(**{ read_timeout: read_timeout * 1000 }.merge(ssl_options))
        @connection = ssl
        ssl.set_endpoint(PolarSSL::SSL::SSL_IS_CLIENT)
        ssl.set_authmode ssl_verify
        ssl.set_rng(ctr_drbg)
        ssl.set_socket(socket)
        ssl.set_hostname(@uri.hostname)
        # wait_for_data! read_timeout
        ssl.handshake
        ssl.blocking = false
      else
        @connection = socket
      end
    end

    def open?
      return false unless @connection
      socket = ssl? ? @connection.socket : @connection
      return !socket.closed?
    end

    def closed?
      !open?
    end

    # Dispatches the specified request object and returns a parser for the
    # response. You can then poll the parser object's #parse method until
    # it is #ready?. This way, you can control the main loop without relying
    # on #when_blocking.
    def dispatch_request(req, &block)
      # prefer keep-alive, but client can change this in the block.
      req['connection'] = 'keep-alive'
      yield req if block_given?
      # we must consume the most recent response body before we can make a new
      # request, or the response body will be interpreted as headers for the
      # one we are about to dispatch.
      @current_response&.response&.body&.read
      establish_connection unless open?
      msg = req.to_s
      @log&.call :send, msg
      @connection.write msg
      Response::Parser.new(@stream)
    end

    # Dispatches the specified request object. If a block is given, the
    # request object is yielded to the block before being sent to the server.
    # Returns the server's response. This method may block, invoking
    # #wait_for_data! if it does.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def request(req, parse: true, &block)
      @current_response = dispatch_request(req, &block)
      parse ? @current_response.response : @current_response
    end

    # Receive up to `count` bytes from the underlying input stream. Should
    # only be called when data is actually expected, as it will wait via
    # #wait_for_data! and time out if the underlying stream does not indicate
    # data is ready to be received.
    private def receive_data(count = 1024)
      wait_for_data! read_timeout
      if bytes_available?
        data = ssl? ? @connection.read(count) : @connection.sysread(count)
        @log&.call :recv, data
        return data
      else
        return ''
      end
    rescue PolarSSL::NetWantRead
      ''
    rescue EOFError
      @connection.close
      return nil
    end

    # Generates a new URI for a request by duplicating the URI that represents
    # the session connection and replacing its path and query string with
    # those provided. `path` will be parsed to check for a query string.
    def request_uri(path)
      uri = @uri.dup
      path, delim, query_string = *path.partition('?')
      uri.path = path
      uri.query_string = query_string.size > 0 ? query_string : nil
      return uri
    end

    # Performs a GET request. If a block is given, the request object is
    # yielded to the block before being sent to the server.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def get(path, parse: true, &block)
      request(Request::Get.new(request_uri(path)), parse: parse, &block)
    end

    # Performs a HEAD request. If a block is given, the request object is
    # yielded to the block before being sent to the server.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def head(path, parse: true, &block)
      request(Request::Head.new(request_uri(path)), parse: parse, &block)
    end

    # Performs a POST request. If a block is given, the request object is
    # yielded to the block before being sent to the server. Body must be a
    # string. Passing an IO as a body is TODO.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def post(path, body = nil, parse: true, &block)
      request(Request::Post.new(request_uri(path), body), parse: parse, &block)
    end

    # Performs a PATCH request. If a block is given, the request object is
    # yielded to the block before being sent to the server. Body must be a
    # string. Passing an IO as a body is TODO.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def patch(path, body = nil, parse: true, &block)
      request(Request::Patch.new(request_uri(path), body), parse: parse, &block)
    end

    # Performs a PUT request. If a block is given, the request object is
    # yielded to the block before being sent to the server. Body must be a
    # string. Passing an IO as a body is TODO.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def put(path, body = nil, parse: true, &block)
      request(Request::Put.new(request_uri(path), body), parse: parse, &block)
    end

    # Performs a DELETE request. If a block is given, the request object is
    # yielded to the block before being sent to the server.
    #
    # If `parse` is `true`, this method will not return until a response is
    # parsed, and an HTTP::Session::Response object is returned. Otherwise,
    # this method will return as soon as possible, and an
    # HTTP::Session::Response::Parser object will be returned.
    def delete(path, parse: true, &block)
      request(Request::Delete.new(request_uri(path)), parse: parse, &block)
    end
  end
end
