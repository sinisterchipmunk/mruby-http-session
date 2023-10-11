module HTTP::Session
  # Parses a request from an HTTP server and populates an HTTP::Session::Request
  # from the stream of data.
  #
  # Usage:
  #    parser = HTTP::Session::Request::Parser.new(io)
  #    parser.request #=> HTTP::Request
  #
  # Note: the parser will begin to parse the request as soon as it is
  # instantiated. On a normal IO or socket, this process will block (not
  # return) until the request headers have been received. It will NOT
  # block until the body has been read. Therefore, it is possible to receive
  # multiple requests and then send multiple responses, but only if you
  # completely consume the body from the first request before moving on to
  # the second:
  #
  #    req1 = HTTP::Session::Request::Parser.new(io).request
  #    assert_equal '/path1', req1.path
  #    req1_body = req1.body.read
  #    #=> string
  #    req2 = HTTP::Session::Response::Parser.new(io).request
  #    assert_equal '/path2', req2.path
  #    req2_body = req2.body.read
  #    #=> string
  #    io.write(req1_response)
  #    io.write(req2_response)
  #
  # IMPORTANT: It is an ERROR to instantiate a second parser on the same
  # byte stream if the request body hasn't been completely read from the
  # first request. In this case, the second parser will attempt to parse
  # the body from the first request as the headers from the second, and
  # this obviously won't end well.
  #
  # Also, since the process of receiving the headers is blocking, it will
  # stall your mruby interpreter until the headers have been received. If
  # you are on an unreliable connection and need to perform other actions
  # while waiting for the data, consider making use of a non-blocking
  # socket and HTTP::Session::Stream. The same applies to reading the request
  # body.
  #
  class Request::Parser < HTTP::Session::Parser
    def initialize(stream)
      super
      @transmission = Request.new
    end

    protected def parse
      receive_path_line if !@have_path_line
      receive_headers   if @have_path_line && !ready?
    end

    def request
      parse until ready?
      @transmission
    end

    private def receive_path_line
      return if @have_path_line
      return unless line = gets
      transmission.verb, space, rest = *line.partition(' ')
      transmission.path, space, transmission.protocol = *rest.rpartition(' ')
      @have_path_line = true
    end
  end
end
