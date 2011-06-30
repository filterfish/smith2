require 'json'

module Smith
  class Messaging
    def initialize(queue_name, options={})
      @channel = AMQP::Channel.new(Smith.connection)
      @exchange = @channel.direct(queue_name.to_s, options)
      @queue = @channel.queue(queue_name.to_s, options).bind(@exchange)
    end

    def send_message(message, options={})
      @exchange.publish({:message => message}.to_json, {:ack => true}.merge(options))
    end

    def receive_message(options={}, &block)
      receive_message_from_queue(@queue, options, &block)
    end

    def receive_message_from_queue(queue, options={}, &block)
      options = {:ack => true}.merge(options)
      if !queue.subscribed?
        queue.subscribe(options) do |header,message|
          if message
            block.call header, JSON.parse(message)["message"]
            header.ack if options[:ack]
          end
        end
      end
    end
  end
end
