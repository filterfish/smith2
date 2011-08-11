require 'json'

module Smith

  class Messaging

    include Logger

    def initialize(queue_name, options={})
      @queue_name = "smith.#{queue_name}"
      @channel = AMQP::Channel.new(Smith.connection)
      @exchange = @channel.direct(@queue_name.to_s, options)
      @queue = @channel.queue(@queue_name.to_s, options).bind(@exchange)
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

    def pop(options={}, &block)
      options = {:ack => true}.merge(options)
      @queue.pop(options) do |metadata, payload|
        data = (payload) ? JSON.parse(payload)["message"] : nil
        block.call data
        metadata.ack
      end
    end

    def number_of_messages
      @queue.status do |num_messages, num_consumers|
        yield num_messages
      end
    end

    def number_of_consumers
      @queue.status do |num_messages, num_consumers|
        yield num_consumers
      end
    end

    def consumers?
      number_of_consumers do |n|
        if n > 0
          yield self
        else
          logger.debug("Nothing listening on #{queue_name}")
        end
      end
    end

    private

    attr_reader :queue_name
  end
end
