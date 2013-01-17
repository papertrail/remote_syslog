require 'socket'
require 'syslog_protocol'

module RemoteSyslog
  class MessageGenerator
    COLORED_REGEXP = /\e\[(?:(?:[0-9]{1,3});){0,2}(?:[0-9]{1,3})m/

    def initialize(socket, options = {})
      @socket = socket

      @parse_fields     = options[:parse_fields]
      @strip_color      = options[:strip_color]
      @exclude_pattern  = options[:exclude_pattern]
      @prepend          = options[:prepend]
      @max_message_size = options[:max_message_size] || 1024

      @packet = SyslogProtocol::Packet.new

      if options[:hostname] && options[:hostname] != ''
        local_hostname = options[:hostname]
      else
        local_hostname = (Socket.gethostname rescue `hostname`.chomp)[/^([^\.]+)/, 1]

        if local_hostname.nil? || local_hostname == ''
          local_hostname = 'localhost'
        end
      end

      @packet.hostname = local_hostname
      @packet.facility = options[:facility] || 'user'
      @packet.severity = options[:severity] || 'notice'
    end

    def transmit(tag, message)
      return if @exclude_pattern && message =~ @exclude_pattern

      message = message.gsub(COLORED_REGEXP, '') if @strip_color
      message = @prepend + message if @prepend

      packet = @packet.dup
      packet.content = message

      if @parse_fields && message =~ @parse_fields
        packet.hostname = $2 if $2 && $2 != ''
        tag             = $3 if $3 && $3 != ''
        packet.content  = $4 if $4 && $4 != ''

        if tag
          packet.tag = tag.gsub(%r{[: \]\[\\]+}, '-')
        end
      end

      unless packet.tag
        packet.tag = tag
      end

      @socket.write(packet.assemble(@max_message_size))
    end
  end
end
