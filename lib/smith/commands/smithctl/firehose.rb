# -*- encoding: utf-8 -*-

module Smith
  module Commands
    class Firehose < CommandBase
      def execute
        queue_name = target.first || '#'
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          channel.topic('amq.rabbitmq.trace', :durable => true) do |exchange|
            channel.queue('smith.firehose', :durable => true) do |queue|
              if correct_direction?
                routing_key = "#{options[:direction]}.#{Smith.config.smith.namespace}.#{queue_name}"

                queue.bind(exchange, :routing_key => routing_key).subscribe do |m, payload|
                  acl_type_cache = AclTypeCache.instance
                  clazz = acl_type_cache.get_by_hash(m.headers['properties']['type'])
                  message = {options[:direction] => clazz.new.parse_from_string(payload)}
                  puts (options[:json_given]) ? message.to_json : message.inspect
                end
              else
                responder.succeed("--direction must be either deliver or publish")
              end
            end
          end
        end
      end

      def options_spec
        b = ["Listens to the rabbitmq firehose for the named queue and prints decoded message to stdout.",
             "  Be warned it can produce vast amounts of outpu.\n",
             "  You _must_ run 'rabbitmqctl trace_on' for this to work."]
        banner b.join("\n")

        opt    :json,       "return the JSON representation of the message", :short => :j
        opt    :direction,  "Show messages that are leaving the broker [deliver|publish]", :short => :d, :type => :string, :default => 'deliver'
      end

      def correct_direction?
        options[:direction] == 'deliver' || options[:direction] == 'publish'
      end
    end
  end
end
