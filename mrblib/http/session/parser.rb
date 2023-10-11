# Abstract class that parses HTTP data from a server. Provides helper
# methods that a subclass can use to parse header and body data.
module HTTP::Session
  class Parser
    class EncodingError < RuntimeError; end

    # The parsed transmission. Before #complete? returns true, it may not be
    # completely well formed. This is either an instance of
    # HTTP::Session::Request or HTTP::Session::Response.
    attr_reader :transmission

    def initialize(stream)
      @stream = stream
      @ready = false
    end

    def ready?
      @ready
    end

    # protected def gets
    #   data = ''
    #   until offset = data.index("\r\n")
    #     packet = @stream.read(1024)
    #     raise EOFError unless packet
    #     data << packet
    #   end
    #   line = data[0, offset]
    #   @stream.unread data[offset + 2, data.size] # remaining data is part of headers
    #   return line
    # end

    # Returns a line of data (up to CR+LF), or else returns `nil` if a line
    # is not available.
    protected def gets
      @tmpbuf ||= ''
      packet = @stream.read(1024)
      raise EOFError unless packet
      @tmpbuf << packet
      if offset = @tmpbuf.index("\r\n")
        line = @tmpbuf[0, offset]
        @stream.unread @tmpbuf[offset + 2, @tmpbuf.size]
        @tmpbuf = ''
        return line
      else
        return nil
      end
    end

    # Attempts to parse a single header. Returns true when the last header
    # has been received.
    protected def receive_headers
      return nil unless line = gets
      if line.size.to_i > 0
        header_name, delim, header_value = *line.partition(':')
        transmission[header_name] = header_value.strip
        return false
      else
        # Blank line, end of headers.
        @ready = true
        receive_body # misnomer, doesn't read anything, just inits the object
        return true
      end
    end

    protected def receive_body
      return transmission.body if @have_body
      @have_body = true
      # choose an appropriate body stream based on transfer encoding
      if transmission['transfer-encoding'] == 'chunked'
        read_chunk_size = Proc.new do
          payload = ''
          payload << @stream.read(1) until payload.index("\r\n") || @stream.eof?
          chunk_size_hex, delim, rest = *payload.partition("\r\n")
          @stream.unread rest
          chunk_size_hex.to_i(16)
        end
        decoded = ''
        transmission.body = Stream.new do |count|
          if count >= decoded.size
            # not enough data decoded; must read at least another chunk
            chunk_size = read_chunk_size.call
            payload = ''
            payload << @stream.read(chunk_size - payload.size) until payload.size >= chunk_size || @stream.eof?
            # put back any extra bytes
            decoded << payload[0, chunk_size]
            @stream.unread payload[chunk_size, payload.size]
            boundary = @stream.read_exactly(2)
            raise EncodingError, "chunk boundary not found" unless @stream.eof? || boundary == "\r\n"
            if chunk_size == 0 then
              # zero chunk, end of body
              transmission.body.eof!
            end
          end
          if decoded.size > 0
            decoded[0, count].tap { decoded = decoded[count, decoded.size] || '' }
          else
            # no more data has been decoded
            nil
          end
        end
      elsif transmission['content-length']
        bytes_remaining = transmission['content-length'].to_i
        transmission.body = Stream.new do |count|
          if bytes_remaining == 0
            nil
          else
            count = bytes_remaining if count > bytes_remaining
            d = @stream.read(count)
            bytes_remaining = d ? bytes_remaining - d.size : 0
            # if content-length bytes were read, end of body
            transmission.body.eof! if bytes_remaining == 0
            d
          end
        end
      else # neither content length nor chunked encoding
        # this violates HTTP/1.1, just read until EOF
        transmission.body = @stream
      end
    end
  end
end
