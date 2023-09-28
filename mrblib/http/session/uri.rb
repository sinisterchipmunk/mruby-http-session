module HTTP::Session
  class URI
    class ParserError < ArgumentError; end

    DEFAULT_PORT_FOR_SCHEME = {
      'https' => 443,
      'http' => 80
    }.freeze

    attr_accessor :scheme, :username, :password, :hostname, :port, :path, :query_string

    def initialize(url)
      @scheme, delim, remainder = *url.to_s.partition("://")
      domain, delim, remainder = *remainder.partition('/')

      # parse credentials, if any
      if credentials_end = domain.index('@')
        credentials = domain[0, credentials_end]
        domain = domain[credentials_end + 1, domain.size]
        @username, @password = *credentials.split(':')
      end

      # parse hostname and port number
      @hostname, delim, @port = domain.partition(':')
      if @port.size > 0 then @port = @port.to_i
      else @port = DEFAULT_PORT_FOR_SCHEME[@scheme]
      end

      # parse path and query string, if present
      @path, delim, @query_string = *remainder.partition('?')
      @path = '/' + @path
      @query_string = nil if @query_string.size == 0

      raise ParserError, "cannot parse #{url.inspect}" unless valid?
    end

    # Returns true if this instance contains valid basic components of a URI,
    # false otherwise.
    def valid?
      [@scheme, @hostname, @port, @path].each do |a|
        return false if a.to_s.size == 0
      end
      return true
    end

    def path_and_query_string
      query_string ? path + "?" + query_string : path
    end

    def ssl?
      scheme == 'https'
    end

    def scheme_and_domain
      str = "#{scheme}://"
      str += "#{username}:#{password}@" if username || password
      str += hostname.to_s
      str += ":#{port}" if port != DEFAULT_PORT_FOR_SCHEME[scheme]
      str
    end

    def to_s
      str = scheme_and_domain
      str += path.to_s
      str += "?#{query_string}" if query_string
      str
    end
  end
end
