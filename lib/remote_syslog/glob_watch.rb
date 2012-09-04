require 'eventmachine-tail'

module RemoteSyslog
  class GlobWatch < EventMachine::FileGlobWatch
    def initialize(path, interval, exclude_files, callback)
      @exclude_files = exclude_files
      @callback = callback

      super(path, interval)
    end

    def file_found(path)
      # Check if we should exclude this file
      if @exclude_files && @exclude_files =~ path
        return
      end

      @callback.call(path)
    end

    def file_deleted(path)
      # Nothing to do
    end
  end
end
