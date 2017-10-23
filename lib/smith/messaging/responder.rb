# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class Responder
      include Smith::Logger
      include EventMachine::Deferrable

      def value(value=nil, &blk)
        logger.debug { "Running responders: #{(value || blk).inspect}" }
        value ||= ((blk) ? blk.call : nil)
        set_deferred_status(:succeeded, value)
      end
    end
  end
end
