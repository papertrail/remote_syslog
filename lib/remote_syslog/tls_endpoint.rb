module RemoteSyslog
  class TlsEndpoint
    class Handler < EventMachine::Connection
      def initialize(endpoint)
        @endpoint = endpoint
        super()
      end

      def connection_completed
        start_tls(:verify_peer => @endpoint.server_cert != nil,
          :cert_chain_file => @endpoint.client_cert_chain,
          :private_key_file => @endpoint.client_private_key)
      end

      def ssl_verify_peer(peer_cert)
        peer_cert = OpenSSL::X509::Certificate.new(peer_cert)
        peer_cert.verify(@endpoint.server_cert.public_key)
      end

      def ssl_handshake_completed
        @endpoint.connection = self
      end

      def unbind
        @endpoint.unbind
      end
    end

    attr_accessor :connection
    attr_reader :server_cert, :client_cert_chain, :client_private_key

    def initialize(address, port, options = {})
      @address            = address
      @port               = port.to_i
      @client_cert_chain  = options[:client_cert_chain]
      @client_private_key = options[:client_private_key]

      if options[:server_cert]
        @server_cert = OpenSSL::X509::Certificate.new(File.read(options[:server_cert]))
      end

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
          @connection.send_data(@queue.join("\n") + "\n")
          @queue = nil
        end
        @connection.send_data(value + "\n")
      else
        (@queue ||= []) << value
      end
    end
  end
end