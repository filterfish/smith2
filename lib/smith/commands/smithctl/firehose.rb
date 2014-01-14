# -*- encoding: utf-8 -*-

module Smith
  module Commands
    class Firehose < CommandBase
      def execute
        queue_name = target.first || '#'
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          channel.topic('amq.rabbitmq.trace', :durable => true) do |exchange|
            channel.queue('smith.firehose', :durable => true) do |queue|
              queue.bind(exchange, :routing_key => "publish.#{Smith.config.smith.namespace}.#{queue_name}").subscribe do |m,p|
                clazz = @acl_type_cache.get_by_hash(m.headers['properties']['type'])
                message = clazz.new.parse_from_string(data)
                puts (options[:json_given]) ? message.to_json : message.inspect
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

        opt    :json ,  "return the JSON representation of the message", :short => :j
      end
    end
  end
end
