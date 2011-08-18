require 'json'

module Smith

  class Messaging

    include Logger

    attr_reader :queue_name

    def initialize(queue_name, options={})
      @queue_name = queue_name
      @channel = AMQP::Channel.new(Smith.connection)

      options.merge!(:durable => true)

      # Set up QOS. If you do not do this then the subscribe in receive_message
      # will get overwelmd and the whole thing will collapse in on itself.
      @channel.prefetch(1)

      @exchange = @channel.direct(namespaced_queue_name, options)
      @queue = @channel.queue(namespaced_queue_name, options).bind(@exchange)
    end

    def send_message(message, options={}, &blk)
      @exchange.publish({:message => message}.to_json, {:ack => true}.merge(options), &blk)
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

    def consumers?(blk=nil, err=proc {logger.debug("Nothing listening on #{queue_name}")})
      number_of_consumers do |n|
        if n > 0
          if blk.respond_to? :call
            blk.call(self)
          else
            yield self
          end
        else
          err.call
        end
      end
    end

    private

    def namespaced_queue_name
      "#{Smith.config.smith.namespace}.#{queue_name}"
    end
  end
end
