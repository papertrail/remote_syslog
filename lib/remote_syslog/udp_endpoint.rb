require 'eventmachine'

module RemoteSyslog
  class UdpEndpoint
    attr_reader :logger

    def initialize(address, port, options = {})
      @address = address
      @port    = port.to_i
      @socket  = EventMachine.open_datagram_socket('0.0.0.0', 0)
      @logger  = options[:logger] || Logger.new(STDERR)

      # Try to resolve the address
      resolve_address

      # Every 60 seconds we'll see if the address has changed
      EventMachine.add_periodic_timer(60) do
        resolve_address
      end
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

    def write(value)
      @socket.send_datagram(value, address, @port)
    end
  end
end
