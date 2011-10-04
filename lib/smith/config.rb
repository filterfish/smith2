# -*- encoding: utf-8 -*-
module Smith
  class Config
    @@config = Optimism do

      agent do
        monitor    true
        singleton  true
      end

      # Options relating to agents only. Don't put agency stuff here.
      agents do
        # If this is a relative path then it's relative to Smith.root_path
        paths ['/home/rgh/dev/ruby/digivizer/agents', '/home/rgh/dev/rails/digivizer-fb-extractor/lib/agent']
      end

      # These directly translate to amqp options so
      # only put options that amqp understands.
      amqp do
        publish do
          ack         true
        end

        pop do
          ack         true
        end

        subscribe do
          ack         true
        end

        exchange do
          durable     true
          auto_delete true
        end

        queue do
          durable     true
          auto_delete true
        end

        broker do
          host        'localhost'
          port        5672
          user        'guest'
          password    'guest'
          vhost       '/'
        end
      end

      # Only put options that eventmachine understands here.
      eventmachine do
        file_descriptors 1024
      end

      logging do
        trace true
        level :debug
        default_pattern "%d [%5p] %7l - %28c:%-3L - %m\n"
        default_date_pattern "%Y/%m/%d %H:%M:%S"
      end

      smith do
        namespace  'smith'
      end
    end

    def self.get
      @@config
    end
  end
end
