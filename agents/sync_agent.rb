# -*- encoding: utf-8 -*-
class SyncAgent < Smith::SynchronousAgent

  options :singleton  => false
  options :monitor    => false
  options :metadata   => "Some sage words about the NullAgent."
  options :queue_name => "agent.null.queue"
  options :children   => 5

  def init
    puts "Oh hi!  I'm awake!"
  end

  def process_message(msg)
    logger.debug("Payload: #{msg.inspect}")
  end
end
