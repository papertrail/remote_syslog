require 'optparse'
require 'yaml'
require 'pathname'
require 'daemons'


module RemoteSyslog
  class Cli
    FIELD_REGEXES = {
      'syslog' => /^(\w+ +\d+ \S+) (\S+) ([^: ]+):? (.*)$/,
      'rfc3339' => /^(\S+) (\S+) ([^: ]+):? (.*)$/
    }

    def self.process!(argv)
      c = new(argv)
      c.parse
      c.run
    end

    def initialize(argv)
      @argv = argv

      @app_name = File.basename($0) || 'remote_syslog'

      @configfile  = '/etc/log_files.yml'
      @strip_color = false

      @daemonize_options = {
        :ARGV         => %w(start),
        :dir_mode     => :system,
        :backtrace    => false,
        :monitor      => false,
        :multiple     => true
      }
    end

    def pid_file=(v)
      m = v.match(%r{^(.+/)?([^/]+?)(\.pid)?$})
      if m[1]
        @daemonize_options[:dir_mode] = :normal
        @daemonize_options[:dir] = m[1]
      end

      @app_name = m[2]
    end

    def parse
      op = OptionParser.new do |opts|
        opts.banner = "Usage:   remote_syslog [options] <path to add'l log 1> .. <path to add'l log n>"
        opts.separator ''
        opts.separator "Example: remote_syslog -c configs/logs.yml -p 12345 /var/log/mysqld.log"
        opts.separator ''
        opts.separator "Options:"

        opts.on("-c", "--configfile PATH", "Path to config (/etc/log_files.yml)") do |v|
          @configfile = File.expand_path(v)
        end
        opts.on("-d", "--dest-host HOSTNAME", "Destination syslog hostname or IP (logs.papertrailapp.com)") do |v|
          @dest_host = v
        end
        opts.on("-p", "--dest-port PORT", "Destination syslog port (514)") do |v|
          @dest_port = v
        end
        opts.on("-D", "--no-detach", "Don't daemonize and detach from the terminal") do
          @no_detach = true
        end
        opts.on("-f", "--facility FACILITY", "Facility (user)") do |v|
          @facility = v
        end
        opts.on("--hostname HOST", "Local hostname to send from") do |v|
          @hostname = v
        end
        opts.on("-P", "--pid-dir DIRECTORY", "Directory to write .pid file in (/var/run/)") do |v|
          @daemonize_options[:dir_mode] = :normal
          @daemonize_options[:dir] = v
        end
        opts.on("--pid-file FILENAME", "PID filename (<program name>.pid)") do |v|
          self.pid_file = v
        end
        opts.on("--parse-syslog", "Parse file as syslog-formatted file") do
          @parse_fields = FIELD_REGEXES['syslog']
        end
        opts.on("-s", "--severity SEVERITY", "Severity (notice)") do |v|
          @severity = v
        end
        opts.on("--strip-color", "Strip color codes") do
          @strip_color = true
        end
        opts.on("--tls", "Connect via TCP with TLS") do
          @tls = true
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
      end

      op.parse!(@argv)

      @files = @argv

      parse_config

      @dest_host ||= 'logs.papertrailapp.com'
      @dest_port ||= 514

      if @files.empty?
        puts "No filenames provided and #{@configfile} not found or malformed."
        puts ''
        puts op
        exit
      end

      # handle relative paths before Daemonize changes the wd to / and expand wildcards
      @files = @files.flatten.map { |f| File.expand_path(f) }.uniq

    end

    def parse_config
      if File.exist?(@configfile)
        config = open(@configfile) do |f|
          YAML.load(f)
        end

        @files += Array(config['files'])

        if config['destination'] && config['destination']['host']
          @dest_host ||= config['destination']['host']
        end

        if config['destination'] && config['destination']['port']
          @dest_port ||= config['destination']['port']
        end

        if config['hostname']
          @hostname = config['hostname']
        end

        if config['parse_fields']
          @parse_fields = FIELD_REGEXES[config['parse_fields']] || Regexp.new(config['parse_fields'])
        end
      end
    end

    def run
      if @no_detach
        start
      else
        Daemons.run_proc(@app_name, @daemonize_options) do
          start
        end
      end
    end

    def start
      EventMachine.run do
        if @tls
          connection = TlsEndpoint.new(@dest_host, @dest_port)
        else
          connection = UdpEndpoint.new(@dest_host, @dest_port)
        end

        @files.each do |path|
          begin
            glob_check_interval = 60
            exclude_files       = []

            EventMachine::FileGlobWatchTail.new(path, RemoteSyslog::Reader,
              glob_check_interval, exclude_files,
              @dest_host, @dest_port,
              :socket => connection, :facility => @facility,
              :severity => @severity, :strip_color => @strip_color,
              :hostname => @hostname, :parse_fields => @parse_fields)
          rescue Errno::ENOENT => e
            puts "#{path} not found, continuing. (#{e.message})"
          end
        end
      end
    end
  end
end
