# encoding: utf-8
module Smith
  class Config
    @@config = Optimism do
      agent do
        monitor    true
        singleton  true
      end

      agents do
        # If this is a relative path then it's relative to Smith.root_path
        default_path 'agents'
      end

      amqp do
        ack        true
        durable    true
        namespace  'smith'
      end

      eventmachine do
        file_descriptors 1024
      end

      logging do
        default_pattern "[%d] %7l - %25c:%-3L - %m\n"
        default_date_pattern "%Y/%m/%d %H:%M:%S"
      end
    end

    def self.get
      @@config
    end
  end
end
