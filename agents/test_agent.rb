# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  options :monitor => false

  def run
    listen_and_reply('agent.test') { |metadata,payload,responder| method(:search).call(metadata, payload, responder) }

    acknowledge_start
    start_keep_alive
    logger.info("Starting #{name}:[#{$$}]")
  end

  private

  def search(metadata, payload, responder)
    responder.value("Hey! mother fucker")
  end
end
