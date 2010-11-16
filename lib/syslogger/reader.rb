module Syslogger
  class Reader < EventMachine::FileTail
    def initialize(path, startpos=-1)
      @program = File.basename(path) || 'syslogger'
      @hostname = `hostname` || 'localhost'
      @hostname.strip!

      super(path, startpos)
      @buffer = BufferedTokenizer.new
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        syslog_to("logs.papertrailapp.com", 514, line)
      end
    end

    def syslog_to(dest_addr, dest_port, pkt)
      sock = nil
      begin
        sock = UDPSocket.open
        sock.send("#{@program} #{pkt}\0", 514, dest_addr, dest_port)
        #sock.send("#{@hostname} #{@program} #{pkt}\0", 514, dest_addr, dest_port)
      rescue IOError, SystemCallError => e
        abort "Failed to send packet: #{e.message}"
      ensure
        sock.close if sock
      end
    end
  end
end
