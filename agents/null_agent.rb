# -*- encoding: utf-8 -*-
class NullAgent < Smith::Agent

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
