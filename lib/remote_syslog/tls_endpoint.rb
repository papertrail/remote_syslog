module RemoteSyslog
  class TlsEndpoint
    class Handler < EventMachine::Connection
      def initialize(endpoint)
        @endpoint = endpoint
        @endpoint.connection = self
        super()
      end

      def connection_completed
        start_tls
      end

      def unbind
        @endpoint.unbind
      end
    end

    attr_accessor :connection

    def initialize(address, port)
      @address = address
      @port    = port.to_i

      # Try to resolve the address
      resolve_address

      # Every 60 seconds we'll see if the address has changed
      EventMachine.add_periodic_timer(60) do
        resolve_address
      end

      connect
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
      EventMachine.connect(address, @port, TlsEndpoint::Handler, self)
    end

    def unbind
      @connection = nil
      connect
    end

    def write(value)
      if @connection
        if @queue
          @queue.each do |line|
            @connection.send_data(line.gsub(/\n/, ' ') + "\n")
          end
          @queue = nil
        end
        @connection.send_data(value + "\n")
      else
        @queue ||= []
        @queue << value
      end
    end
  end
end