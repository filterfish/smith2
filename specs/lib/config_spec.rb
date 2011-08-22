# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Smith::Config do

  before(:each) do
    @config = Smith::Config.get
  end

  it 'should set meaning defaults' do
    @config.eventmachine.file_descriptors.should == 1024
    @config.amqp.publish.ack.should == true
    @config.amqp.exchange.durable.should == true

    @config.smith.namespace.should == 'smith'
  end
end
