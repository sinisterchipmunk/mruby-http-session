module HTTP::Session
  class Transmission; end
  class Response < Transmission
    attr_accessor :protocol
    attr_reader :status_code
    attr_accessor :status_text
    attr_accessor :body
    attr_accessor :headers
    alias status status_code

    def initialize(status_code = nil, status_text = nil, protocol = 'HTTP/1.1',
                   headers: {}, body: nil)
      super protocol, body
      @status_code = status_code
      @status_text = status_text
      headers.each { |k, v| self[k] = v }
    end

    # Sets the status code, converting it to an integer unless it's `nil`.
    def status_code=(i)
      @status_code = i&.to_i
    end

    # Serialies this request's status line and headers into a string suitable
    # to send over the network. Unlike #to_s, this method does not include the
    # body, so it won't exhaust memory and won't consume the IO (if it is
    # one), but with the drawback that you must handle the body yourself.
    # If #body is an IO-like, then the transport encoding will be set to
    # `chunked`. In that case, you can use the #chunk_s helper method.
    #
    # Example:
    #    rsp.body = body_io
    #    io.write(rsp.header_s)
    #    io.write(rsp.chunk_s(body_io.read(1024))) until body_io.eof?
    #
    def header_s
      "#{protocol} #{status_code} #{status_text}\r\n" + super
    end
  end
end
