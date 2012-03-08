# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  options :monitor => false

  def run
    n = 0

    receiver('agent.fast_test') do |r|
      acl = Smith::ACL::Payload.new(:default)
      sender('agent.barf') do |send_queue|
        send_queue.publish_and_receive(acl.content("#{n +=1 } hey!")) do |r|
          puts "echoing payload: #{r.payload}"
        end
      end
    end
  end
end
