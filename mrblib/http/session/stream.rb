module HTTP::Session
  class Stream
    # Block is called when bytes are desired to be read. It takes the number
    # of desired bytes as input. It returns as many bytes as are currently
    # available, as a string, up to the size given. It is allowed to return
    # less bytes than requested, but not more. It returns `nil` on EOF.
    #
    # Initial buffer is any data you'd like to be read at the beginning of
    # the stream, before any other bytes are read. Block won't be invoked
    # until initial buffer is completely drained.
    #
    # If no block is given, a default block returns EOF immediately. This can
    # be useful if you just want to use `initial_buffer` without any real
    # underlying data stream.
    def initialize(initial_buffer = '', &on_read)
      @buffer = initial_buffer
      @on_read = on_read || Proc.new { nil }
      @underlying_eof = false
    end

    def eof?
      @buffer.size == 0 && @underlying_eof
    end

    # forces the underlying input stream to be treated as end-of-file.
    def eof!
      @underlying_eof = true
    end

    # Puts the given string into the front of the internal buffer, to be
    # returned by the next call to #read.
    def unread(str)
      if str && str.size > 0
        @buffer = str.to_s + @buffer
      end
    end

    private def drain_buffer(count)
      @buffer[0, count].tap { @buffer = @buffer[count, @buffer.size] || '' }
      # crashes on mruby 2.1.2
      # @buffer.slice! 0...count
    end

    private def read_into_buffer(n)
      d = @on_read.call(n)
      if d
        # @buffer << d.to_s
        @buffer += d.to_s
      else
        eof!
      end
    end

    private def buffer_all
      return if @underlying_eof
      # read (up to) 2kb at a time until EOF
      read_into_buffer(2048) until @underlying_eof
    end

    private def buffer_at_most(n)
      return if n <= 0
      return if @underlying_eof
      return if @buffer.size > 0
      read_into_buffer(n)
    end

    private def buffer_exactly(n)
      read_into_buffer(n - @buffer.size) until @buffer.size >= n || @underlying_eof
    end

    # Read up to `count` bytes and return them. If `count` is omitted/nil,
    # reads all bytes until EOF.
    def read(count = nil)
      return nil if eof?
      if count.nil? then buffer_all
      else buffer_at_most(count)
      end
      return drain_buffer(count || @buffer.size)
    end

    # Reads exactly `count` bytes, blocking until EOF or they have all
    # been read. On EOF, less than `count` bytes might be returned. Returns
    # a string of `count` bytes, otherwise.
    def read_exactly(count)
      return nil if eof?
      buffer_exactly(count)
      return drain_buffer(count)
    end

    def buffered_size
      @buffer.size
    end
  end

  class OutputStream < Stream
    def closed?; !!@closed; end
    def close; @closed = true; end
    def open?; !closed?; end
    def socket; self; end
    def write(s)
      raise Errno::ESHUTDOWN, "write failed: stream is closed" if closed?
      @buffer << s.to_s
    end
  end
end
