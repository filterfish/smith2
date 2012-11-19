# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Requeue

      include Logger

      def initialize(message, metadata, opts={})
        @message = message
        @metadata = metadata
        @queue = opts[:queue]
        @exchange = opts[:exchange]

        @count = opts[:count] || 3
        @delay = opts[:delay] || 5
        @strategy = opts[:strategy] || :linear

        @on_requeue = opts[:on_requeue] || ->(message, current_count, total_count) { logger.info { "Requeuing message on queue: #{@queue}" } }
        @on_requeue_error = opts[:on_requeue_error] || ->(message, current_count, total_count) { logger.info { "Requeue limit reached: [#{@count}] for queue: #{@queue}" } }
      end

      def requeue
        requeue_with_strategy do
          opts = @queue.opts.clone.tap do |o|
            o.delete(:queue)
            o.delete(:exchange)

            o[:headers] = increment_requeue_count
            o[:routing_key] = @queue.name
            o[:type] = @metadata.type
          end

          logger.verbose { "Requeuing to: #{@queue.name}. [options]: #{opts}" }
          logger.verbose { "Requeuing to: #{@queue.name}. [message]: #{@message}" }

          @exchange.publish(ACL::Payload.new(ACL::Factory.create(@metadata.type, @message)).encode, opts)
        end
      end

      private

      def current_requeue_number
        @metadata.headers['requeue'] || 0
      end

      def increment_requeue_count
        @metadata.headers.tap do |m|
          m['requeue'] = (m['requeue']) ? m['requeue'] + 1 : 1
        end
      end

      def requeue_with_strategy(&block)
        if current_requeue_number < @count
          method = "#{@strategy}_strategy".to_sym
          if respond_to?(method, true)
            cumulative_delay = send(method, @delay)
            @on_requeue.call(cumulative_delay, current_requeue_number + 1)
            EM.add_timer(cumulative_delay) do
              block.call(cumulative_delay, current_requeue_number + 1)
            end
          else
            raise RuntimeError, "Unknown requeue strategy. #{method}"
          end
        else
          @on_requeue_error.call(cumulative_delay, current_requeue_number)
        end
      end

      def exponential_no_initial_delay_strategy(delay)
        delay * (2 ** current_requeue_number - 1)
      end

      def exponential_strategy(delay)
        delay * (2 ** current_requeue_number)
      end

      def linear_strategy(delay)
        delay * (current_requeue_number + 1)
      end
    end
  end
end
