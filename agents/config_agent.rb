# -*- encoding: utf-8 -*-

require 'smith/agent_config'

class ConfigAgent < Smith::Agent

  options :monitor => false

  def run
    config = Smith::AgentConfig.new(Smith.config.agency.cache_path, 'agent_config')

    Smith::Messaging::Receiver.new('agent.config.request', :type => :agent_config_request) do |r|
      r.subscribe do |payload, r|
        logger.info("Reading config for: #{payload.agent}")
        c = config.for(payload.agent) || MultiJson.dump({})
        r.reply(Smith::ACL::Factory.create(:agent_config_response, :config => c))
      end
    end

    Smith::Messaging::Receiver.new('agent.config.update', :type => :agent_config_update) do |r|
      r.subscribe do |payload, r|
        logger.info("Updating config for: #{payload.agent}")
        config.update(payload.agent, payload.value)
      end
    end
  end
end
