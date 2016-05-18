# -*- encoding: utf-8 -*-
class NullAgent < Smith::Agent

  options :singleton => false
  options :statistics => false
  options :metadata => "Some sage words about the NullAgent."

  def run
    receiver('agent.null.queue', :auto_ack => false, :auto_delete => false).subscribe(method(:worker))
  end

  def worker(payload, receiver)
    logger.debug("Payload: #{payload.inspect.gsub(/\r|\n/n, ', ')}")
    receiver.ack
  end

end
