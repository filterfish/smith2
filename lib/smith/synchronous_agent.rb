class Smith::SynchronousAgent < Smith::Agent
  def run
    if defined(:prefork_init)
      prefork_init
    end

    if Smith.config.agent.children.nil?
      raise ArgumentError,
            "No children count specified (use options :children => N)"
    end

    Smith.config.agent.children.to_i.times do
      Process.fork { run_child }
    end

    loop do
      wait
      Process.fork { run_child }
    end
  end

  def run_child
    if defined?(:init)
      init
    end

    if @queue_name.nil?
      raise ArgumentError,
            "No queue name specified"
    end

    receiver(@queue_name, :auto_ack => false, :auto_delete => false) do |queue|
      queue.subscribe do |payload, receiver|
        handle_message(payload)
        receiver.ack
      end
    end
  end
end
