require 'test/unit'
require 'remote_syslog/message_generator'

class MessageGeneratorTest < Test::Unit::TestCase
  def test_prepend_log_prefix
    socket = []
    def socket.write(packet)
      self << packet
    end
    generator = RemoteSyslog::MessageGenerator.new(socket, {:log_prefix => 'crazy_prefix'})
    generator.transmit("tag", "message")
    assert_match /crazy_prefix /, socket[0]
  end
end