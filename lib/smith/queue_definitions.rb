# -*- encoding: utf-8 -*-

module Smith
  module QueueDefinitions
    Agency_control = QueueDefinition.new("#{Smith.hostname}.agency.control", :auto_delete => false, :durable => false, :persistent => false, :strict => true)
    Agent_keepalive = QueueDefinition.new("#{Smith.hostname}.agent.keepalive", :auto_delete => false, :durable => false)
    Agent_lifecycle = QueueDefinition.new("#{Smith.hostname}.agent.lifecycle", :auto_delete => false, :durable => false)

    Agent_stats = QueueDefinition.new('agent.stats', :durable => false, :auto_delete => false)

    # Something tells me that I've crossed line with this.
    Agent_control = ->(uuid) { QueueDefinition.new("agent.control.#{uuid}", :durable => false, :auto_delete => true) }
  end
end
