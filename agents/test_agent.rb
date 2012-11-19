# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  options :monitor => false

  def run
    receiver('agent.test').subscribe do |payload|

      sender('agent.null') do |send_queue|

        work = ->(n, iter) do
          send_queue.publish(Smith::ACL::Factory.create(:default, :n => n))
          iter.next
        end

        done = -> { puts "done" }

        EM::Iterator.new(0..9).each(work, done)
      end
    end
  end
end
