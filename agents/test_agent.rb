# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  options :monitor => false

  def run
    subscribe_and_reply('agent.test', :threads => true) do |metadata,payload,responder|
      method(:search).call(metadata, payload, responder)
    end

    subscribe('agent.fast_test', :threads => false) do |metadata,payload|
      publish('agent.barf', Smith::ACL::Payload.new(:default).content("hey!"))
    end

    acknowledge_start
    start_keep_alive
    logger.info("Starting #{name}:[#{$$}]")
  end

  private

  def search(metadata, payload, responder)
    t1 = Time.now.to_f
    puts "searching"
    sleep(10)
    t2 = Time.now.to_f
    puts "finished searching"
    responder.value("finished searching after #{t2 - t1}")
  end
end
