# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'smith'
require 'pp'

Smith::ACL::Default

describe Smith::ACL::Factory do

  include Smith::ACL

  before(:all) do
    Smith.load_acls
    @message = "This is a message using the default encoder"
  end

  context "Default ACL" do
    it 'should create a new Default ACL class' do
      default = Smith::ACL::Factory.create(Default)
      default.should be_an_instance_of(Smith::ACL::Default)
    end

    it 'should set content content hash' do
      default = Smith::ACL::Factory.create(Default, :bar => 'humbug')
      default.to_hash.should == {:bar => 'humbug'}
    end

    it 'should set content' do
      default = Smith::ACL::Factory.create(Default)
      default.command = 'hey!'
      default.args = 'boooooooo'

      default.to_hash.should == {:command => "hey!", :args => 'boooooooo'}
    end

    it 'should set content using a block' do
      default = Smith::ACL::Factory.create(Default) do |acl|
        acl.bob = 'hey!'
        acl.sid ='boooooooo'
      end

      default.to_hash.should ==  {:bob => "hey!", :sid => "boooooooo"}
    end

    it 'should raise an error if block & content hash are given.' do
      expect do
        default = Smith::ACL::Factory.create(Default, :sid => 'bang') do |acl|
          acl.bob = 'wrong'
        end
      end.to raise_error(ArgumentError, 'You cannot give a content hash and a block.')
    end

    it 'should return valid json.' do
      default = Smith::ACL::Factory.create(Default) do |acl|
        acl.bob = 'hey!'
        acl.sid ='boooooooo'
      end

      default.to_json.should == '{"bob":"hey!","sid":"boooooooo"}'
    end
  end

  context "Non-default ACL" do
    it 'should create a new AgencyCommand ACL class' do
      default = Smith::ACL::Factory.create(Default)
      default.should be_an_instance_of(Smith::ACL::Default)
    end

    it 'should set the type' do
      command = Smith::ACL::Factory.create(AgencyCommand) do |acl|
        acl.command = 'hey!'
        acl.args = ['ar1', 'arg2']
      end

      command._type.should == 'agency_command'
    end

    it 'should allow content to be set using a block' do
      command = Smith::ACL::Factory.create(AgencyCommand) do |acl|
        acl.command = 'hey!'
        acl.args = ['ar1', 'arg2']
      end

      command.to_hash.should == {:command=>"hey!", :args=>["ar1", "arg2"]}
    end
  end

  context "Nested ACL" do
    it 'should instantiate a nested ACL' do
      acl = Smith::ACL::Factory.create(AgentStats::QueueStats)
      acl.should be_an_instance_of(Smith::ACL::AgentStats::QueueStats)
    end

    it 'should set the type' do
      acl = Smith::ACL::Factory.create(AgentStats::QueueStats)
      acl._type.should == AgentStats::QueueStats
    end

    it 'should set content' do
      acl = Smith::ACL::Factory.create(AgentStats::QueueStats) do |a|
        a.name = 'name'
        a.type = 'type'
        a.length = 6
      end

      acl.to_hash.should == {:name => 'name', :type => 'type', :length => 6}
    end
  end
end
