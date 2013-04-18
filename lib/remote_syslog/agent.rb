require 'eventmachine'
require 'servolux'

require 'remote_syslog/eventmachine_reader'
require 'remote_syslog/file_tail_reader'
require 'remote_syslog/glob_watch'
require 'remote_syslog/message_generator'
require 'remote_syslog/udp_endpoint'
require 'remote_syslog/tls_endpoint'
require 'remote_syslog/tcp_endpoint'

module RemoteSyslog
  class Agent < Servolux::Server
    # Who should we connect to?
    attr_accessor :destination_host, :destination_port

    # Should use TCP?
    attr_accessor :tcp

    # Should use TLS?
    attr_accessor :tls

    # TLS settings
    attr_accessor :client_cert_chain, :client_private_key, :server_cert

    # syslog defaults
    attr_accessor :facility, :severity, :hostname

    # Other settings
    attr_accessor :strip_color, :parse_fields, :prepend

    # Exclude messages matching pattern
    attr_accessor :exclude_pattern

    # Files (can be globs)
    attr_reader :files

    # Exclude files matching pattern
    attr_accessor :exclude_file_pattern

    # How often should we check for new files?
    attr_accessor :glob_check_interval

    # Should we use eventmachine to tail?
    attr_accessor :eventmachine_tail

    def initialize(options = {})
      @files = []
      @glob_check_interval = 10
      @eventmachine_tail = options.fetch(:eventmachine_tail, true)

      unless logger = options[:logger]
        logger = Logger.new(STDERR)
        logger.level = Logger::ERROR
      end

      super('remote_syslog', :logger => logger, :pid_file => options[:pid_file])
    end

    def log_file=(file)
      @log_file = File.expand_path(file)

      level = self.logger.level
      self.logger = Logger.new(file)
      self.logger.level = level
    end

    def redirect_io!
      if @log_file
        STDOUT.reopen(@log_file, 'a')
        STDERR.reopen(@log_file, 'a')
        STDERR.sync = STDOUT.sync = true
      end
    end

    def files=(files)
      @files = [ @files, files ].flatten.compact.uniq
    end

    def watch_file(file)
      if eventmachine_tail
        RemoteSyslog::EventMachineReader.new(file,
          :callback => @message_generator.method(:transmit),
          :logger => logger)
      else
        RemoteSyslog::FileTailReader.new(file,
          :callback => @message_generator.method(:transmit),
          :logger => logger)
      end
    end

    def run
      EventMachine.run do
        EM.error_handler do |e|
          logger.error "Unhandled EventMachine Exception: #{e.class}: #{e.message}:\n\t#{e.backtrace.join("\n\t")}"
        end

        if @tls
          max_message_size = 10240

          connection = TlsEndpoint.new(@destination_host, @destination_port,
            :client_cert_chain => @client_cert_chain,
            :client_private_key => @client_private_key,
            :server_cert => @server_cert,
            :logger => logger)
        elsif @tcp
          max_message_size = 20480

          connection = TcpEndpoint.new(@destination_host, @destination_port,
            :logger => logger)
        else
          max_message_size = 1024
          connection = UdpEndpoint.new(@destination_host, @destination_port,
            :logger => logger)
        end

        @message_generator = RemoteSyslog::MessageGenerator.new(connection, 
          :facility => @facility, :severity => @severity, 
          :strip_color => @strip_color, :hostname => @hostname, 
          :parse_fields => @parse_fields, :exclude_pattern => @exclude_pattern,
          :prepend => @prepend, :max_message_size => max_message_size)

        files.each do |file|
          RemoteSyslog::GlobWatch.new(file, @glob_check_interval, 
            @exclude_file_pattern, method(:watch_file))
        end
      end
    end

    def endpoint_mode
      @endpoint_mode ||= if @tls
        'TCP/TLS'
      elsif @tcp
        'TCP'
      else
        'UDP'
      end
    end

    def before_stopping
      EM.stop
    end
  end
end
