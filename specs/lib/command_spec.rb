# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module Smith
  module Commands
    class Agents < Command
      def execute(target)
      end
    end
  end
end

describe Smith::Command do
  before(:each) do
  end

  it 'should create methods corresponding to the hash passed in' do
    c = Smith::Command.run(:agents, 'NullAgent', {:agency => 'agency_object',  :agents => "agents_object"}, :auto_load => false)

    c.respond_to?(:agency).should be_true
    c.respond_to?(:agents).should be_true
    c.respond_to?(:target).should be_true

    c.agency.should == 'agency_object'
    c.agents.should == 'agents_object'
    c.target.should == 'NullAgent'
  end
end
