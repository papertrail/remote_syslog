require 'optparse'
require 'yaml'
require 'pathname'
require 'servolux'

require 'remote_syslog/agent'

module RemoteSyslog
  class Cli
    FIELD_REGEXES = {
      'syslog' => /^(\w+ +\d+ \S+) (\S+) ([^: ]+):? (.*)$/,
      'rfc3339' => /^(\S+) (\S+) ([^: ]+):? (.*)$/
    }

    DEFAULT_PID_FILES = [
      "/var/run/remote_syslog.pid",
      "#{ENV['HOME']}/run/remote_syslog.pid",
      "#{ENV['HOME']}/tmp/remote_syslog.pid",
      "#{ENV['HOME']}/remote_syslog.pid",
      "#{ENV['TMPDIR']}/remote_syslog.pid",
      "/tmp/remote_syslog.pid"
    ]

    DEFAULT_CONFIG_FILE = '/etc/log_files.yml'

    def self.process!(argv)
      c = new(argv)
      c.parse
      c.run
    end

    attr_reader :program_name

    def initialize(argv)
      @argv = argv
      @program_name = File.basename($0)

      @strip_color = false
      @exclude_pattern = nil

      @daemonize_options = {
        :ARGV         => %w(start),
        :dir_mode     => :system,
        :backtrace    => false,
        :monitor      => false,
      }

      @agent = RemoteSyslog::Agent.new(:pid_file => default_pid_file)
    end

    def is_file_writable?(file)
      directory = File.dirname(file)

      (File.directory?(directory) && File.writable?(directory) && !File.exists?(file)) || File.writable?(file)
    end

    def default_pid_file
      DEFAULT_PID_FILES.each do |file|
        return file if is_file_writable?(file)
      end
    end

    def parse
      op = OptionParser.new do |opts|
        opts.banner = "Usage: #{program_name} [OPTION]... <FILE>..."
        opts.separator ''

        opts.separator "Options:"

        opts.on("-c", "--configfile PATH", "Path to config (/etc/log_files.yml)") do |v|
          @configfile = v
        end
        opts.on("-d", "--dest-host HOSTNAME", "Destination syslog hostname or IP (logs.papertrailapp.com)") do |v|
          @agent.destination_host = v
        end
        opts.on("-p", "--dest-port PORT", "Destination syslog port (514)") do |v|
          @agent.destination_port = v
        end
        opts.on("-D", "--no-detach", "Don't daemonize and detach from the terminal") do
          @no_detach = true
        end
        opts.on("-f", "--facility FACILITY", "Facility (user)") do |v|
          @agent.facility = v
        end
        opts.on("--hostname HOST", "Local hostname to send from") do |v|
          @agent.hostname = v
        end
        opts.on("-P", "--pid-dir DIRECTORY", "DEPRECATED: Directory to write .pid file in") do |v|
          puts "Warning: --pid-dir is deprecated. Please use --pid-file FILENAME instead"
          @pid_directory = v
        end
        opts.on("--pid-file FILENAME", "Location of the PID file (default #{@agent.pid_file})") do |v|
          @agent.pid_file = v
        end
        opts.on("--parse-syslog", "Parse file as syslog-formatted file") do
          @agent.parse_fields = FIELD_REGEXES['syslog']
        end
        opts.on("-s", "--severity SEVERITY", "Severity (notice)") do |v|
          @agent.severity = v
        end
        opts.on("--strip-color", "Strip color codes") do
          @agent.strip_color = true
        end
        opts.on("--tcp", "Connect via TCP (no TLS)") do
          @agent.tcp = true
        end
        opts.on("--tls", "Connect via TCP with TLS") do
          @agent.tls = true
        end


        opts.on("--new-file-check-interval INTERVAL", OptionParser::DecimalInteger,
          "Time between checks for new files") do |v|
          @agent.glob_check_interval = v
        end

        opts.separator ''
        opts.separator 'Advanced options:'

        opts.on("--[no-]eventmachine-tail", "Enable or disable using eventmachine-tail") do |v|
          @agent.eventmachine_tail = v
        end
        opts.on("--debug-log FILE", "Log internal debug messages") do |v|
          @agent.log_file = v
        end

        severities = Logger::Severity.constants + Logger::Severity.constants.map { |s| s.downcase }
        opts.on("--debug-level LEVEL", severities, "Log internal debug messages at level") do |v|
          @agent.logger.level = Logger::Severity.const_get(v.upcase)
        end

        opts.separator ""
        opts.separator "Common options:"

        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.on("--version", "Show version") do
          puts RemoteSyslog::VERSION
          exit(0)
        end

        opts.separator ''
        opts.separator "Example:"
        opts.separator "    $ #{program_name} -c configs/logs.yml -p 12345 /var/log/mysqld.log"
      end

      op.parse!(@argv)

      @files = @argv.dup.delete_if { |a| a.empty? }

      if @configfile
        if File.exists?(@configfile)
          parse_config(@configfile)
        else
          error "The config file specified could not be found: #{@configfile}"
        end
      elsif File.exists?(DEFAULT_CONFIG_FILE)
        parse_config(DEFAULT_CONFIG_FILE)
      end

      if @files.empty?
        error "You must specify at least one file to watch"
      end

      @agent.destination_host ||= 'logs.papertrailapp.com'
      @agent.destination_port ||= 514

      # handle relative paths before Daemonize changes the wd to / and expand wildcards
      @files = @files.flatten.map { |f| File.expand_path(f) }.uniq

      @agent.files = @files

      if @pid_directory
        if @agent.pid_file
          @agent.pid_file = File.expand_path("#{@pid_directory}/#{File.basename(@agent.pid_file)}")
        else
          @agent.pid_file = File.expand_path("#{@pid_directory}/remote_syslog.pid")
        end
      end

      # We're dealing with an old-style pid_file
      if @agent.pid_file && File.basename(@agent.pid_file) == @agent.pid_file
        default_pid_dir = File.dirname(default_pid_file)

        @agent.pid_file = File.join(default_pid_dir, @agent.pid_file)

        if File.extname(@agent.pid_file) == ''
          @agent.pid_file << '.pid'
        end
      end

      @agent.pid_file ||= default_pid_file

      if !@no_detach && !::Servolux.fork?
        @no_detach = true

        puts "Fork is not supported in this Ruby environment. Running in foreground."
      end
    rescue OptionParser::ParseError => e
      error e.message, true
    end

    def parse_config(file)
      config = YAML.load_file(file)

      @files += Array(config['files'])

      if config['destination'] && config['destination']['host']
        @agent.destination_host ||= config['destination']['host']
      end

      if config['destination'] && config['destination']['port']
        @agent.destination_port ||= config['destination']['port']
      end

      if config['hostname']
        @agent.hostname = config['hostname']
      end

      @agent.server_cert        = config['ssl_server_cert']
      @agent.client_cert_chain  = config['ssl_client_cert_chain']
      @agent.client_private_key = config['ssl_client_private_key']

      if config['parse_fields']
        @agent.parse_fields = FIELD_REGEXES[config['parse_fields']] || Regexp.new(config['parse_fields'])
      end

      if config['exclude_patterns']
        @agent.exclude_pattern = Regexp.new(config['exclude_patterns'].map { |r| "(#{r})" }.join('|'))
      end

      if config['exclude_files']
        @agent.exclude_file_pattern = Regexp.new(config['exclude_files'].map { |r| "(#{r})" }.join('|'))
      end

      if config['new_file_check_interval']
        @agent.glob_check_interval = config['new_file_check_interval']
      end

      if config['prepend']
        @agent.prepend = config['prepend']
      end
    end

    def run
      Thread.abort_on_exception = true

      if @agent.tls && !EventMachine.ssl?
        error "TLS is not supported by eventmachine installed on this system.\nThe openssl-devel/openssl-dev package must be installed before installing eventmachine."
      end

      if @no_detach
        puts "Watching #{@agent.files.length} files/globs. Sending to #{@agent.destination_host}:#{@agent.destination_port} (#{@agent.endpoint_mode})."
        @agent.run
      else
        daemon = Servolux::Daemon.new(:server => @agent, :after_fork => method(:redirect_io))

        if daemon.alive?
          error "Already running at #{@agent.pid_file}. To run another instance, specify a different `--pid-file`.", true
        end

        puts "Watching #{@agent.files.length} files/globs. Sending to #{@agent.destination_host}:#{@agent.destination_port} (#{@agent.endpoint_mode})."
        daemon.startup
      end
    rescue Servolux::Daemon::StartupError => e
      case message = e.message[/^(Child raised error: )?(.*)$/, 2]
      when /#<Errno::EACCES: (.*)>$/
        error $1
      else
        error message
      end
    rescue Interrupt
      exit(0)
    end

    def redirect_io
      @agent.redirect_io!
    end


    def error(message, try_help = false)
      puts "#{program_name}: #{message}"
      if try_help
        puts "Try `#{program_name} --help' for more information."
      end
      exit(1)
    end
  end
end
