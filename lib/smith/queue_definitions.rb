# -*- encoding: utf-8 -*-

module Smith
  module QueueDefinitions
    Agent_keepalive = QueueDefinition.new("#{Smith.hostname}.agent.keepalive", :auto_delete => false, :durable => true)
    Agent_lifecycle = QueueDefinition.new("#{Smith.hostname}.agent.lifecycle", :auto_delete => false, :durable => true)

    Agent_stats = QueueDefinition.new('agent.stats', :durable => true, :auto_delete => true)

    # Something tells me that I've crossed line with this.
    Agent_control = ->(uuid) { QueueDefinition.new("agent.control.#{uuid}", :durable => false, :auto_delete => true) }

    Agency_control = ->(node=nil) {
      QueueDefinition.new("#{node || Smith.hostname}.agency.control", :auto_ack => false, :durable => true, :persistent => false, :strict => true)
    }
  end
end
