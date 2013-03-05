# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Queue

      extend Util

      class << self
        def messages?(queue_def, &blk)
          number_of_messages(queue_def) do |n|
            yield n > 0
          end
        end

        def consumers?(queue_def)
          number_of_consumers(queue_def) do |n|
            yield n > 0
          end
        end

        def number_of_consumers(queue_def)
          status(queue_def) do |_, number_consumers|
            yield number_consumers
          end
        end

        def number_of_messages(queue_def)
          status(queue_def) do |number_messages, _|
            yield number_messages
          end
        end

        def status(queue_def)
          open_channel do |channel, ok|

            queue_def = queue_def.is_a?(QueueDefinition) ? queue_def : QueueDefinition.new(queue_def, :passive => true)
            channel.queue(*queue_def.to_a).status do |number_messages, number_consumers|
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
