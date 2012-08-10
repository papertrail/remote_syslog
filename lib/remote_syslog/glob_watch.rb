require 'eventmachine-tail'

module RemoteSyslog
  class GlobWatch < EventMachine::FileGlobWatch
    def initialize(path, interval, callback)
      super(path, interval)
      @callback = callback
    end

    def file_found(path)
      @callback.call(path)
    end

    def file_deleted(path)
      # Nothing to do
    end
  end
end
