# -*- encoding: utf-8 -*-
module Smith
  class Config

    @@config = Optimism.new.tap do |o|
      o.amqp do |a|
        a.publish do |p|
          p.ack = true
          p.headers = {}
        end

        a.pop.ack = true
        a.subscribe.ack = true
      end
    end._merge!(Optimism.require_file(['/etc/smith/smithrc', "#{ENV['HOME']}/.smithrc"]))

    def self.get
      @@config
    end
  end
end
