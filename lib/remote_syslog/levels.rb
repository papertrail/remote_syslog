module RemoteSyslog
  class Levels
    SEVERITIES = {
      :emerg => 0,
      :alert => 1,
      :crit  => 2,
      :err   => 3,
      :warning => 4,
      :notice  => 5,
      :info  => 6,
      :debug => 7
    }.freeze
    
    FACILITIES = {
      :kern => (0<<3),
      :user => (1<<3),
      :mail => (2<<3),
      :daemon => (3<<3),
      :auth => (4<<3),
      :syslog => (5<<3),
      :lpr  => (6<<3),
      :news => (7<<3),
      :uucp => (8<<3),
      :cron => (9<<3),
      :authpriv => (10<<3),
      :ftp  => (11<<3),
      :local0 => (16<<3),
      :local1 => (17<<3),
      :local2 => (18<<3),
      :local3 => (19<<3),
      :local4 => (20<<3),
      :local5 => (21<<3),
      :local6 => (22<<3),
      :local7 => (23<<3)
    }.freeze
  end
end
