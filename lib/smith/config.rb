# -*- encoding: utf-8 -*-
module Smith
  class Config

    @@config = Optimism.new.tap do |o|
      o.amqp.publish.ack = true
      o.amqp.subscribe.ack = true
      o.amqp.pop.ack = true
    end._merge!(Optimism.require_file(['/etc/smith/smithrc', "#{ENV['HOME']}/.smithrc"]))

    def self.get
      @@config
    end
  end
end
