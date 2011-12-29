# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'pp'

describe Smith::Messaging::AmqpOptions do

  before(:all) do
    @options = Smith::Messaging::AmqpOptions.new
    @options.queue_name = "long.queue"
  end

  it 'should return the correct default exchange options' do
    @options.exchange.should == {:durable => true, :auto_delete => true}
  end

  it 'should return the correct default queue options' do
    @options.queue.should == {:durable => true, :auto_delete => true}
  end

  it 'should return the correct default publish options' do
    @options.publish.should == {:ack => true, :routing_key => "long.queue"}
  end

  it 'should return the correct default subscribe options' do
    @options.subscribe.should == {:ack => true}
  end

  it 'should expand and merge short options to the proper amqp options' do
    @options.subscribe(:strict => true).should == {:ack => true, :immediate => true, :mandatory => true}
  end
end
