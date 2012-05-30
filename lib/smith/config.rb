# -*- encoding: utf-8 -*-
module Smith
  class Config

    @@config = Optimism.new.tap do |o|
      o.agency do |a|
        a.timeout = 30
      end

      o.agent do |a|
        a.monitor = false
        a.singleton = true
        a.metadata = ''
      end

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
    end._merge!(Optimism.require('/etc/smith/smithrc', "#{ENV['HOME']}/.smithrc"))

    # I'm sure there's a better way of doing this ...
    @@config.agency['acl_cache_path'] = Pathname.new(@@config.agency.cache_path).join('acl')
    @@config.agency['acl_path'] = "#{Pathname.new(__FILE__).dirname.join('messaging').join('acl')}#{File::PATH_SEPARATOR}#{@@config.agency['acl_path']}"

    def self.get
      @@config
    end
  end
end
