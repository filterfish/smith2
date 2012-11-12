# -*- encoding: utf-8 -*-

module Smith
  class QueueFactory
    def initialize
      @cache = Cache.new
    end

    # Convenience method that returns a Sender object.
    def sender(queue_name, opts={}, &blk)
      create(queue_name, :sender, opts, &blk)
    end

    # Convenience method that returns a Receiver object.
    def receiver(queue_name, opts={}, &blk)
      create(queue_name, :receiver, opts, &blk)
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

    def create(queue_name, type, opts={}, &blk)
      key = "#{type}:#{queue_name}"
      if @cache[key]
        blk.call(@cache[key])
      else
        update_cache(key, opts) do |o|
          case type
          when :receiver
            Messaging::Receiver.new(queue_name, o, &blk)
          when :sender
            Messaging::Sender.new(queue_name, o, &blk)
          end
        end
      end
    end

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
