# -*- encoding: utf-8 -*-
class NullAgent < Smith::Agent

  options :monitor => false
  options :metadata => "Some sage words about the NullAgent."

  def run
    receiver('agent.barf', :auto_ack => false) do |r|
      logger.debug("Payload: #{r.payload.inspect.gsub(/\r|\n/n, ', ')}")

      r.ack
    end
  end
end
