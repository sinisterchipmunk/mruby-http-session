module HTTP::Session
  # Base class for HTTP messages such as Request and Response.
  class Transmission
    attr_accessor :protocol
    attr_reader :headers, :body
    alias http_version protocol

    def initialize(protocol, body)
      @headers = {}
      self.protocol = protocol
      self.body = body
    end

    def body=(body)
      @body = body
    end

    def [](header_name)
      @headers[header_name.downcase]
    end

    def []=(header_name, value)
      @headers[header_name.downcase] = value
    end

    private def full_headers
      if body.respond_to?(:read)
        { 'transfer-encoding' => 'chunked' }.merge(@headers)
      else
        { 'content-length' => body.to_s.size.to_s }.merge(@headers)
      end
    end

    # Serialies this request's headers into a string suitable to send over the
    # network, not including the first line of the transmission. Unlike #to_s,
    # this method does not include the body, so it won't exhaust memory and
    # won't consume the IO (if it is one), but with the drawback that you must
    # handle the body yourself. If #body is an IO-like, then the transport
    # encoding will be set to `chunked`. In that case, you can use the
    # #chunk_s helper method.
    #
    # Example:
    #    tsmsn.body = body_io
    #    io.write("GET / HTTP/1.1\r\n")
    #    io.write(tsmsn.header_s)
    #    io.write(tsmsn.chunk_s(body_io.read(1024))) until body_io.eof?
    #
    def header_s
      r = ''
      full_headers.sort.each do |k, v|
        r << "#{k.capitalize}: #{v}\r\n"
      end
      r << "\r\n"
      r
    end

    # Helper method that returns a string containing a well-formed chunk for
    # the given str. Note that when doing your own chunking, you MUST end the
    # response with a zero-length chunk (that is: `chunk_s("")`).
    #
    # Example:
    #    tsmsn.body = body_io
    #    io.write("GET / HTTP/1.1\r\n")
    #    io.write(tsmsn.header_s)
    #    io.write(tsmsn.chunk_s(body_io.read(1024))) until body_io.eof?
    #
    def chunk_s(str)
      str.size.to_s(16) + "\r\n" + str + "\r\n"
    end

    # Serializes this request into a string suitable to send over the network,
    # not including the first line of the transmission.
    # Warning: if `body` is an IO-like, this method will read it until EOF!
    #
    # Example:
    #    io.write("GET / HTTP/1.1\r\n")
    #    io.write(tsmsn.to_s)
    #
    def to_s
      body_str = body.respond_to?(:read) ? body.read.to_s : body.to_s
      header_s + body_str
    end
  end
end
