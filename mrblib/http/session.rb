module HTTP
  module Session
    class << self
      # Optional block which can be invoked whenever a new HTTP::Session is
      # created. Block takes the session as an argument. Useful for unit
      # testing.
      #
      # Example:
      #
      #    HTTP::Session.on_new = Proc.new do |session|
      #      case session.uri.to_s
      #      when 'http://www.google.com'
      #        # mock up a google connection without actually connecting to it
      #      else
      #        # any other URI will make a real connection.
      #      end
      #    end
      #
      attr_accessor :on_new

      def new(*args, &block)
        HTTP::Session::Session.new(*args, &block).tap do |session|
          on_new&.call session
        end
      end
    end
  end
end
