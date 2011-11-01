# -*- encoding: utf-8 -*-
module Smith
  class Config
    @@config = Optimism do

      agent do |c|
        c.monitor    = true
        c.singleton  = true
      end

      # Options relating to agents only. Don't put agency stuff here.
      agents do |c|
        # If this is a relative path then it's relative to Smith.root_path
        #paths ['/home/rgh/dev/ruby/digivizer-core/agents', '/home/rgh/dev/rails/digivizer-fb-extractor/lib/agents']
        c.paths = ['agents']
      end

      # These directly translate to amqp options so
      # only put options that amqp understands.
      # WARNING: UNDER NO CIRCUMSTANCES CHANGE ack TO false.
      amqp do |c|
        c.publish do
          c.ack  = true
        end

        c.pop do |c|
          c.ack  = true
        end

        c.subscribe do |c|
          c.ack  = true
        end

        exchange do |c|
          c.durable     = true
          c.auto_delete = true
        end

        queue do |c|
          c.durable     = true
          c.auto_delete = true
        end

        broker do |c|
          c.host        = 'localhost'
          c.port        = 5672
          c.user        = 'guest'
          c.password    = 'guest'
          c.vhost       = '/'
        end
      end

      # Only put options that eventmachine understands here.
      eventmachine do |c|
        c.file_descriptors = 1024
      end

      logging do |c|
        c.trace = true
        c.level = :debug
        c.default_pattern = "%d [%5p] %7l - %28c:%-3L - %m\n"
        c.default_date_pattern = "%Y/%m/%d %H:%M:%S"
      end

      smith do |c|
        c.namespace  = 'smith'
      end
    end

    def self.get
      @@config
    end
  end
end
