# encoding: utf-8
module Smith
  class Config
    @@config = Optimism do
      eventmachine do
        file_descriptors 1024
      end

      amqp do
        namespace 'smith'
        ack       true
        durable   true
      end
    end

    def self.get
      @@config
    end
  end
end
