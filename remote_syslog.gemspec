# https://github.com/mojombo/rakegem
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'remote_syslog'
  s.version           = '1.6.11'
  s.date              = '2013-01-14'
  s.rubyforge_project = 'remote_syslog'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = 'Monitor plain text log file(s) for new entries and send to remote syslog collector'
  s.description = "Lightweight daemon to tail one or more log files and transmit UDP syslog messages to a remote syslog host (centralized log aggregation). Generates UDP packets itself instead of depending on a system syslog daemon, so it doesn't affect system-wide logging configuration."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = [ 'Troy Davis', 'Eric Lindvall' ]
  s.email    = [ 'troy@sevenscale.com', 'eric@sevenscale.com' ]
  s.homepage = 'http://github.com/papertrail/remote_syslog'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## If your gem includes any executables, list them here.
  s.executables = ['remote_syslog']
  s.default_executable = 'remote_syslog'

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  #s.add_dependency('DEPNAME', [">= 1.1.0", "< 2.0.0"])
  s.add_dependency 'servolux'
  s.add_dependency 'file-tail'
  s.add_dependency 'eventmachine', [ '>= 0.12.10', '< 1.1' ]
  s.add_dependency 'eventmachine-tail', [ '>= 0.6.4' ]
  s.add_dependency 'syslog_protocol', [ '~> 0.9.2' ]
  s.add_dependency 'em-resolv-replace'

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
  #s.add_development_dependency('DEVDEPNAME', [">= 1.1.0", "< 2.0.0"])

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    Gemfile
    LICENSE
    README.md
    Rakefile
    bin/remote_syslog
    examples/com.papertrailapp.remote_syslog.plist
    examples/log_files.yml.example
    examples/log_files.yml.example.advanced
    examples/remote_syslog.init.d
    examples/remote_syslog.supervisor.conf
    examples/remote_syslog.upstart.conf
    lib/remote_syslog.rb
    lib/remote_syslog/agent.rb
    lib/remote_syslog/cli.rb
    lib/remote_syslog/eventmachine_reader.rb
    lib/remote_syslog/file_tail_reader.rb
    lib/remote_syslog/glob_watch.rb
    lib/remote_syslog/message_generator.rb
    lib/remote_syslog/tcp_endpoint.rb
    lib/remote_syslog/tls_endpoint.rb
    lib/remote_syslog/udp_endpoint.rb
    remote_syslog.gemspec
    test/unit/message_generator_test.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }
end
