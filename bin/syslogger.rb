#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'
require 'eventmachine-tail'
require 'lib/syslogger/reader'

def main(args)
  if args.length == 0
    puts "Usage: #{$0} <path> [path2] [...]"
    return 1
  end

  EventMachine.run do
    args.each do |path|
      EventMachine::file_tail(path, Syslogger::Reader)
    end
  end
end

exit(main(ARGV))
