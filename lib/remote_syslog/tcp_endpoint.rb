require 'eventmachine'

module RemoteSyslog
  # Additional class that uses TCP but no TLS.  Has the benefit of a greater max packet size
  class TcpEndpoint
    class Handler < EventMachine::Connection
      def initialize(endpoint)
        @endpoint = endpoint
        super()
      end

      def connection_completed
        @endpoint.connection = self
      end

      def unbind
        @endpoint.unbind
      end
    end

    attr_accessor :connection

    attr_reader :logger

    def initialize(address, port, options = {})
      @address            = address
      @port               = port.to_i
      @queue_limit        = options[:queue_limit] || 10_000
      @logger             = options[:logger] || Logger.new(STDERR)

      # Try to resolve the address
      resolve_address

      # Every 60 seconds we'll see if the address has changed
      EventMachine.add_periodic_timer(60) do
        resolve_address
      end

      connect
    end

    def connection=(conn)
      port, ip = Socket.unpack_sockaddr_in(conn.get_peername)
      logger.debug "Connected to #{ip}:#{port}"
      @connection = conn
    end

    def resolve_address
      request = EventMachine::DnsResolver.resolve(@address)
      request.callback do |addrs|
        @cached_ip = addrs.first
      end
    end

    def address
      @cached_ip || @address
    end

    def connect
      logger.debug "Connecting to #{address}:#{@port}"
      EventMachine.connect(address, @port, TcpEndpoint::Handler, self)
    end

    def unbind
      @connection = nil

      EventMachine.add_timer(1) do
        connect
      end
    end

    def write(value)
      if @connection
        if @queue
          @connection.send_data(@queue.join("\n") + "\n")
          @queue = nil
        end
        @connection.send_data(value + "\n")
      else
        (@queue ||= []) << value

        # Make sure our queue does not get to be too big
        @queue.shift if @queue.length > @queue_limit
      end
    end
  end
end
