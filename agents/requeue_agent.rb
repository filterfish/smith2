# -*- encoding: utf-8 -*-
class RequeueAgent < Smith::Agent

  options :metadata => "An example of how to use requeuing"

  def run
    receiver('example.requeue', :auto_ack => false, :prefetch => 1024, &method(:requeue_setup)).subscribe(method(:worker))
  end

  def requeue_setup(queue)
    queue.requeue_parameters(:count => 10, :delay => 2, :strategy => :linear)

    queue.on_requeue_limit do |acl, actual_retry_count, total_retry_count, last_delay|
      pp({:message => "requeue limit reached", :total_retry_count => total_retry_count, :last_delay => last_delay })
      Squash::Ruby.notify("requeue limit reached", :message => acl.to_hash, :total_retry_count => total_retry_count, :last_delay => last_delay) 

      # Work arund for the current requeue implementation. If we don't do thi
      # we'll lose the ACL.
      sender(queue.queue_name) do |republish_queue|
        republish_queue.publish(acl) do
          raise "Requeue limit reached for message: #{acl.class}"
        end
      end
    end
  end

  def worker(payload, receiver)
    logger.debug("Payload: #{payload.inspect}")
    receiver.requeue
    receiver.ack
  end
end
