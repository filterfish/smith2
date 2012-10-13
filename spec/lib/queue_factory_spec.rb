# -*- encoding: utf-8 -*-

require 'spec_helper'

describe Smith::QueueFactory do

  context "basic operations" do
    let(:factory) { Smith::QueueFactory.new }

    it 'should create a factory instance' do
      factory.should be_a_kind_of(Smith::QueueFactory)
    end

    it 'should raise an exception when an incorrect queue type is instantiated' do
      expect { factory.create('random.queue.name', :pants) }.to raise_error(ArgumentError)
    end

    it 'should return all instantiated queues' do

      queues = {}
      queues['random.receiver.queue.name'] = factory.create('random.receiver.queue.name', :receiver)
      queues['random.sender.queue.name'] = factory.create('random.sender.queue.name', :sender)

      factory.queues.size.should == 2

      factory.each_queue do |queue|
        queue.should == factory.queues[queue.denormalized_queue_name]
      end
    end

    it 'should not return :dont_cache queues' do
      factory.create('random.sender.queue.name', :sender, :dont_cache => true)

      factory.queues.size.should == 0
    end
  end

  context "sender queues" do
    let(:factory) { Smith::QueueFactory.new }

    it 'should instantiate a queue with default options.' do
      queue = factory.create('random.queue.name', :sender)
      queue.should be_a_kind_of(Smith::Messaging::Sender)
      queue.send(:queue_name).should == 'smith.random.queue.name'
      queue.denormalized_queue_name.should == 'random.queue.name'

      queue.send(:options).queue.should == Smith.config.amqp.queue.to_hash
    end

    it 'should correctly set additional queue options' do
      queue = factory.create('random.queue.name', :receiver, :auto_delete => false)

      queue.send(:options).queue.should == Smith.config.amqp.queue.to_hash.merge(:auto_delete => false)
    end
  end

  context "receive queues" do
    let(:factory) { Smith::QueueFactory.new }

    it 'should instantiate a queue with default options.' do
      queue = factory.create('random.queue.name', :receiver)
      queue.should be_a_kind_of(Smith::Messaging::Receiver)
      queue.send(:queue_name).should == 'smith.random.queue.name'
      queue.denormalized_queue_name.should == 'random.queue.name'

      queue.send(:options).queue.should == Smith.config.amqp.queue.to_hash
    end

    it 'should correctly set additional queue options' do
      queue = factory.create('random.queue.name', :receiver, :auto_delete => false)

      queue.send(:options).queue.should == Smith.config.amqp.queue.to_hash.merge(:auto_delete => false)
    end

    it 'should correctly set endpoint options' do
      queue = factory.create('random.queue.name', :receiver, :threading => true, :auto_ack => false)

      queue.threading?.should == true
      queue.auto_ack?.should == false
    end
  end
end
