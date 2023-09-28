# Parses a response from an HTTP server and populates an HTTP::Response
# from the stream of data.
#
# Usage:
#    parser = HTTP::Session::Response::Parser.new(io)
#    parser.response #=> HTTP::Response
#
# Note: the parser will begin to parse the response as soon as it is
# instantiated. On a normal IO or socket, this process will block (not
# return) until the response headers have been received. It will NOT
# block until the body has been read. Therefore, it is possible to send
# multiple requests and then receive multiple responses, but only if you
# completely consume the body from the first request before moving on to
# the second:
#
#    io.write(request1.to_s)
#    io.write(request2.to_s)
#    rsp1 = HTTP::Response::Parser.new(io).response
#    assert_equal 200, rsp1.status
#    rsp1_body = rsp1.body.read
#    #=> string
#    rsp2 = HTTP::Response::Parser.new(io).response
#    assert_equal 200, rsp2.status
#    rsp2_body = rsp2.body.read
#    #=> string
#
# IMPORTANT: It is an ERROR to instantiate a second parser on the same
# byte strema if the response body hasn't been completely read from the
# first request. In this case, the second parser will attempt to parse
# the body from the first response as the headers from the second, and
# this obviously won't end well.
#
# Also, since the process of receiving the headers is blocking, it will
# stall your mruby interpreter until the headers have been received. If
# you are on an unreliable connection and need to perform other actions
# while waiting for the data, consider making use of a non-blocking
# socket and HTTP::Stream. The same applies to reading the response body.
#
module HTTP::Session
  class Response::Parser < HTTP::Session::Parser
    alias response transmission

    def initialize(stream)
      super
      @transmission = Response.new
      receive_status_line
      receive_headers
      receive_body
    end

    private def receive_status_line
      line = gets
      transmission.protocol, space, rest = *line.partition(' ')
      transmission.status_code, space, transmission.status_text = *rest.partition(' ')
    end
  end
end
