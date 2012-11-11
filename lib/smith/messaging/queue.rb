# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Queue

      extend Util

      class << self
        def messages?(queue_name, &blk)
          number_of_messages(queue_name) do |n|
            yield n > 0
          end
        end

        def consumers?(queue_name)
          number_of_consumers(queue_name) do |n|
            yield n > 0
          end
        end

        def number_of_consumers(queue_name)
          status(queue_name) do |_, number_consumers|
            yield number_consumers
          end
        end

        def number_of_messages(queue_name)
          status(queue_name) do |number_messages, _|
            yield number_messages
          end
        end

        def status(queue_name)
          open_channel do |channel, ok|
            channel.queue(normalise(queue_name), :passive => true).status do |number_messages, number_consumers|
              yield number_messages, number_consumers
              channel.close
            end
          end
        end

        def channel
          open_channel do |channel, ok|
            yield channel
          end
        end
      end
    end
  end
end
