# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Subscribe < CommandBase
      def execute
        Messaging::Receiver.new(target.first, amqp_opts) do |receiver|
          receiver.subscribe do |payload, r|
            pp payload
          end
        end
      end

      private

      def amqp_opts
        {}.tap do |amqp|
          [:durable, :auto_delete, :header].each do |k|
            if k == :header && !options[k].nil?
              amqp[k] = eval(options[k])
            else
              amqp[k] = options[k]
            end
          end
        end
      end

      def options_spec
        banner "Subcribe to the named queue and print and received messages to stdout.", "<queue>"

        opt    :durable,     "amqp durable option", :default => false
        opt    :auto_delete, "amqp auto-delete option", :default => false
        opt    :header,      "amqp headers as json", :type => :string
      end
    end
  end
end
