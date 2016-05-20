# -*- encoding: utf-8 -*-
class ThreadAgent < Smith::Agent

  options :singleton => false
  options :monitor => false
  options :metadata => "ThreadAgent — an example of how to use threads."

  def run

    EventMachine.threadpool_size = 100

    receiver('agent.thread.queue', :auto_ack => false, :prefetch => 1024, :threading => true) do |queue|
      queue.subscribe do |payload, receiver|
        logger.debug("Payload: #{payload.to_s.size}")
        sleep(2)
        logger.debug { 'acked' }
        receiver.ack
      end
    end
  end
end
