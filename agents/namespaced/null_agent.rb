# -*- encoding: utf-8 -*-
module Namespaced
  class NullAgent < ::Smith::Agent

    options :singleton => false
    options :monitor => false
    options :metadata => "Some sage words about the NullAgent."

    def run
      receiver('agent.null.queue', :auto_ack => false, :auto_delete => false) do |queue|
        queue.subscribe do |payload, receiver|
          logger.debug("Payload: #{payload.inspect.gsub(/\r|\n/n, ', ')}")
          receiver.ack
        end
      end
    end
  end
end
