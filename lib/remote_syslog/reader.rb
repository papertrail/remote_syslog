module RemoteSyslog
  class Reader < EventMachine::FileTail
    def initialize(path, dest_addr, dest_port, options = {})
      @dest_addr = dest_addr
      @dest_port = dest_port.to_i
      
      @socket = options[:socket] || EventMachine.open_datagram_socket('0.0.0.0', 0)
      @program = options[:program] || File.basename(path) || 'remote_syslog'
      @hostname = options[:hostname] || `hostname`.strip
      @hostname = 'localhost' unless @hostname && @hostname != ''
      
      if options[:severity]
        @severity = severity_value(options[:severity]) || raise(ArgumentError, "Invalid severity: #{options[:severity]} (valid: #{severities.keys.join(', ')})")
      else
        @severity = severity_value(:notice)
      end
      
      if options[:facility]
        @facility = facility_value(options[:facility]) || raise(ArgumentError, "Invalid facility: #{options[:facility]} (valid: #{facilities.keys.join(', ')}")
      else
        @facility = facility_value(:user)
      end

      super(path, -1)
      @buffer = BufferedTokenizer.new
    end
  
    def receive_data(data)
      @buffer.extract(data).each do |line|
        transmit(line)
      end
    end

    def transmit(message)
      time ||= Time.now
      day = time.strftime('%b %d').sub(/0(\d)/, ' \\1')

      @socket.send_datagram("<#{(@facility) + @severity}>#{day} #{time.strftime('%T')} #{@hostname} #{@program}: #{message}", @dest_addr, @dest_port)
    end
    
    def facility_value(f)
      f.is_a?(Integer) ? f*8 : facilities[f.to_sym]
    end
    
    def severity_value(s)
      s.is_a?(Integer) ? s : severities[s.to_sym]
    end
    
    def facilities
      Levels::FACILITIES
    end
    
    def severities
      Levels::SEVERITIES
    end
  end
end
