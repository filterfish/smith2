# -*- encoding: utf-8 -*-

module Smith
  class QueueFactory
    def initialize
      @cache = Cache.new
    end

    def queue(name, type, opts={})
      case type
      when :receiver
        Messaging::Receiver.new(name, opts).tap { |queue| @cache.update(name, queue) }
      when :sender
        Messaging::Sender.new(name, opts).tap { |queue| @cache.update(name, queue) }
      else
        raise ArgumentError, "unknown queue type"
      end
    end

    def queues
      if block_given?
        @cache.each do |queue|
          yield queue
        end
      else
        @cache
      end
    end
  end
end
