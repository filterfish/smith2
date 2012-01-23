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
      o.logging do |l|
        l.trace = false
        l.level = :debug
        l.appender = 'Stdout'
        l.default_pattern = '%d [%5p] %7l - %34c:%-3L - %m\\n'
        l.default_date_pattern = '%Y/%m/%d %H:%M:%S.%N'
      end
    end._merge!(Optimism.require_file(['/etc/smith/smithrc', "#{ENV['HOME']}/.smithrc"]))

    # I'm sure there's a better way of doing this ...
    @@config.agency['protocol_buffer_cache_path'] = "#{@@config.agency.cache_path.to_s}#{File::SEPARATOR}pb"

    def self.get
      @@config
    end
  end
end
