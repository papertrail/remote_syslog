require 'socket'
require 'eventmachine'
require 'eventmachine-tail'
require 'em-dns-resolver'
require 'syslog_protocol'

module RemoteSyslog
  class Reader < EventMachine::FileTail
    COLORED_REGEXP = /\e\[(?:(?:[34][0-7]|[0-9]);){0,2}(?:[34][0-7]|[0-9])m/

    def initialize(path, destination_address, destination_port, options = {})
      super(path, -1)

      @destination_address = destination_address
      @destination_port    = destination_port.to_i

      @parse_fields = options[:parse_fields]
      @strip_color = options[:strip_color]

      @socket = options[:socket] || EventMachine.open_datagram_socket('0.0.0.0', 0)

      @buffer = BufferedTokenizer.new

      @packet = SyslogProtocol::Packet.new

      local_hostname = options[:hostname] || (Socket.gethostname rescue `hostname`.chomp)
      if local_hostname.nil? || local_hostname.empty?
        local_hostname = 'localhost'
      end

      @packet.hostname = local_hostname
      @packet.facility = options[:facility] || 'user'
      @packet.severity = options[:severity] || 'notice'
      @packet.tag      = options[:program]  || File.basename(path) || File.basename($0)

      # Make sure the tag isn't too long
      if @packet.tag.length > 32
        @packet.tag = @packet.tag[0..31]
      end

      # Try to resolve the destination address
      resolve_destination_address

      # Every 60 seconds we'll see if the address has changed
      EventMachine.add_periodic_timer(60) do
        resolve_destination_address
      end
    end

    def resolve_destination_address
      request = EventMachine::DnsResolver.resolve(@destination_address)
      request.callback do |addrs|
        @cached_destination_ip = addrs.first
      end
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        transmit(line)
      end
    end

    def destination_address
      @cached_destination_ip || @destination_address
    end

    def transmit(message)
      message = message.gsub(COLORED_REGEXP, '') if @strip_color

      packet = @packet.dup
      packet.content = message

      if @parse_fields
        if message =~ @parse_fields
          packet.hostname = $2
          packet.tag      = $3
          packet.content  = $4
        end
      end

      @socket.send_datagram(packet.assemble, destination_address, @destination_port)
    end
  end
end
