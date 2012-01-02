# -*- encoding: utf-8 -*-

module Smith
  class QueueFactory
    def initialize
      @cache = Cache.new
    end

    def create(queue_name, type, opts={})
      if @cache[queue_name]
        @cache[queue_name]
      else
        update_cache(queue_name, opts) do |o|
          case type
          when :receiver
            Messaging::Receiver.new(queue_name, o)
          when :sender
            Messaging::Sender.new(queue_name, o)
          else
            raise ArgumentError, "unknown queue type"
          end
        end
      end
    end

    # Simple wrapper around create that runs Endpoint#ready and calls the block
    def queue(queue_name, type, opts={}, &blk)
      create(queue_name, type, opts).ready { |queue| blk.call(queue) }
    end

    # Convenience method that returns a Sender object. .ready is called by
    # this method.
    def sender(queue_name, opts={}, &blk)
      queue(queue_name, :sender, opts) { |sender| blk.call(sender) }
    end

    # Convenience method that returns a Receiver object. .ready is called by
    # this method.
    def receiver(queue_name, opts={}, &blk)
      queue(queue_name, :receiver, opts) { |receiver| blk.call(receiver) }
    end

    # Passes each queue to the supplied block.
    def each_queue
      @cache.each do |queue|
        yield queue
      end
    end

    # Returns all queues as a hash, with the queue name being the key.
    def queues
      @cache
    end

    private

    def update_cache(queue_name, opts, &blk)
      dont_cache = (opts.has_key?(:dont_cache)) ? opts.delete(:dont_cache) : false
      if dont_cache
        blk.call(opts)
      else
        @cache.update(queue_name, blk.call(opts))
      end
    end
  end
end
