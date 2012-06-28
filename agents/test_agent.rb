# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  options :monitor => false

  def run
    n = 0

    sender('agent.barf') do |send_queue|

      logger.debug { "Setting up reply handler." }

      send_queue.on_reply do |r|
        puts "Echoing payload: #{r.payload}"
      end

      receiver('agent.fast_test') do |queue|
        puts "Sending message to #{send_queue.queue_name}"
        send_queue.publish(Smith::ACL::Payload.new(:default).content("#{n +=1 } hey!"))
      end
    end
  end
end
