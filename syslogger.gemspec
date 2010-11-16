# encoding: utf-8

Gem::Specification.new do |s|
  s.name         = 'syslogger'
  s.version      = 0.1
  s.authors      = ['Seven Scale']
  s.email        = 'troy@sevenscale.com'
  s.homepage     = 'http://github.com/sevenscale'
  s.summary      = 'Monitor flat file log for new entries and send to remote syslog'
  s.description  = 'Monitor flat file log for new entries and send to remote syslog'
  s.files        = Dir['{lib/**/*,[A-Z]*}'] + Dir['{bin/*}']

  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'
  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'eventmachine'
  s.add_dependency 'eventmachine-tail'
end
