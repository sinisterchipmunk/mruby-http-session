module HTTP::Session
  class Transmission; end
  class Request < Transmission
    DEFAULT_USER_AGENT = 'ruby'

    attr_reader :verb, :uri

    def initialize(verb = :get, url = nil, body = nil)
      super('HTTP/1.1', body)
      self.verb = verb
      self.uri = url
      self['accept'] = '*/*'
      self['user-agent'] = DEFAULT_USER_AGENT
    end

    def verb=(v)
      @verb = v.kind_of?(String) ? v.downcase.to_sym : v
    end

    def path
      @uri&.path
    end

    def path=(path)
      if @uri
        self.uri = File.join(@uri.scheme_and_domain, path)
      else
        self.uri = File.join("http://127.0.0.1", path)
      end
    end

    def uri=(url)
      @uri = url.kind_of?(URI) ? url : url && URI.new(url)
      self['host'] = @uri&.hostname
    end

    def scheme;                uri&.scheme;                end
    def username;              uri&.username;              end
    def password;              uri&.password;              end
    def hostname;              uri&.hostname;              end
    def port;                  uri&.port;                  end
    def path;                  uri&.path;                  end
    def query_string;          uri&.query_string;          end
    def path_and_query_string; uri&.path_and_query_string; end

    # Serialies this request's path line and headers into a string suitable
    # to send over the network. Unlike #to_s, this method does not include the
    # body, so it won't exhaust memory and won't consume the IO (if it is
    # one), but with the drawback that you must handle the body yourself.
    # If #body is an IO-like, then the transport encoding will be set to
    # `chunked`. In that case, you can use the #chunk_s helper method.
    #
    # Example:
    #    req.body = body_io
    #    io.write(req.header_s)
    #    io.write(req.chunk_s(body_io.read(1024))) until body_io.eof?
    #
    def header_s
      "#{verb.to_s.upcase} #{path_and_query_string} #{protocol}\r\n" + super
    end
  end
end
