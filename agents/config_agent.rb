# -*- encoding: utf-8 -*-

require 'smith/agent_config'

class ConfigAgent < Smith::Agent

  options :monitor => false

  def run
    config = Smith::AgentConfig.new('/var/cache/smith', 'agent_config')

    receiver('agent.config.request', :type => :agent_config_request) do |r|
      logger.info("Reading config for: #{r.payload.agent}")

      pp config.for(r.payload.agent)

      r.reply do |responder|
        responder.value(config.for(r.payload.agent))
      end
    end

    receiver('agent.config.update', :type => :agent_config_update) do |r|
      p = r.payload
      logger.info("Updating config for: #{p.agent}")
      config.update(p.agent, p.value)
    end
  end
end
