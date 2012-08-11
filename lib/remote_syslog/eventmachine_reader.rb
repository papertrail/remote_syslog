require 'eventmachine'
require 'eventmachine-tail'
require 'em-dns-resolver'

# Force eventmachine-tail not to change the encoding
# This will allow ruby 1.9 to deal with any file data
old_verbose, $VERBOSE = $VERBOSE, nil
EventMachine::FileTail::FORCE_ENCODING = false
$VERBOSE = old_verbose

module RemoteSyslog
  class EventMachineReader < EventMachine::FileTail
    def initialize(path, options = {}, &block)
      @callback = options[:callback] || block
      @buffer = BufferedTokenizer.new
      @logger = options[:logger] || Logger.new(STDERR)

      @tag = options[:program] || File.basename(path)

      # Remove characters that can't be in a tag
      @tag = @tag.gsub(%r{[: \]\[\\]+}, '-')

      # Make sure the tag isn't too long
      if @tag.length > 32
        @tag = @tag[0..31]
      end

      @logger.debug "Watching #{path} with EventMachineReader"

      super(path, -1)
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        @callback.call(@tag, line)
      end
    end

    def on_exception(exception)
      @logger.error "Exception: #{exception.class}: #{exception.message}\n\t#{exception.backtrace.join("\n\t")}"
    end
  end
end
