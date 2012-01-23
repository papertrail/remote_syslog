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

      @parse_fields = options[:parse_fields]
      @strip_color = options[:strip_color]
      @exclude_pattern = options[:exclude_pattern]

      @socket = options[:socket] || UdpEndpoint.new(destination_address, destination_port)

      @buffer = BufferedTokenizer.new

      @packet = SyslogProtocol::Packet.new

      local_hostname = options[:hostname] || (Socket.gethostname rescue `hostname`.chomp)
      if local_hostname.nil? || local_hostname.empty?
        local_hostname = 'localhost'
      end

      @packet.hostname = local_hostname
      @packet.facility = options[:facility] || 'user'
      @packet.severity = options[:severity] || 'notice'

      tag = options[:program]  || File.basename(path) || File.basename($0)

      # Make sure the tag isn't too long
      if tag.length > 32
        tag = tag[0..31]
      end
      @packet.tag = tag
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        transmit(line)
      end
    end

    def transmit(message)
      return if @exclude_pattern && message =~ @exclude_pattern

      message = message.gsub(COLORED_REGEXP, '') if @strip_color

      packet = @packet.dup
      packet.content = message

      if @parse_fields
        if message =~ @parse_fields
          packet.hostname = $2 if $2 && $2 != ''
          packet.tag      = $3 if $3 && $3 != ''
          packet.content  = $4 if $4 && $4 != ''
        end
      end

      @socket.write(packet.assemble)
    end
  end
end
