# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'pp'

describe Smith::ACL::Payload do

  include Smith::ACL

  before(:all) do
    @message = "This is a message using the default encoder"
  end

  context "Default Encoder" do
    it 'should encode a message' do
      Marshal.load(Smith::ACL::Payload.new(:default).content(@message).encode).should == @message
    end

    it 'should encode a message using the block form' do
      payload = Smith::ACL::Payload.new(:default).content do |p|
        p.blah = 'blah'
      end

      Marshal.load(payload.encode).should == {:blah => 'blah'}
    end

    it "should decode a message" do
      Smith::ACL::Payload.decode(Marshal.dump(@message)).should == @message
    end

    it "should encode a nil message" do
      Marshal.load(Smith::ACL::Payload.new(:default).content(nil).encode).should == nil
    end

    it "should decode a nil message" do
      Smith::ACL::Payload.decode(Marshal.dump(nil)).should == nil
    end
  end

  # context "Agency Command Encoder" do
  #   let(:message1) { {:command => "list"} }
  #   let(:message2) { {:command => "list", :args => ["--all", "--l"]} }
  #   let(:message3) { {:command => :list} }
  #   let(:message4) { {:incorrect_command => 'list'} }

  #   it "should encode and decode a correct message when the message type is specified as a symbol" do
  #     Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agency_command).content(message1).encode, :agency_command).should == message1
  #     Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agency_command).content(message2).encode, :agency_command).should == message2
  #   end

  #   it "should encode and decode a correct message when the message type is specified as a class" do

  #     Smith::ACL::Payload.decode(Smith::ACL::Payload.new(Encoder::AgencyCommand).content(message1).encode, Encoder::AgencyCommand).should == message1
  #     Smith::ACL::Payload.decode(Smith::ACL::Payload.new(Encoder::AgencyCommand).content(message2).encode, Encoder::AgencyCommand).should == message2
  #   end

  #   it "should access the decoded message fields using accessor mesthods." do
  #     decoded_message = Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agency_command).content(message2).encode, :agency_command)
  #     decoded_message.command.should == 'list'
  #     decoded_message.args.should == ["--all", "--l"]
  #   end

  #   it "should throw an TypeException when an message of incorect type is used" do
  #     expect { Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agency_command).content(message3).encode, :agency_command) }.to raise_error(TypeError)
  #   end

  #   it "should throw an RequiredFieldNotSetError when a message with an incorrect field is used" do
  #     expect { Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agency_command).content(message4).encode, :agency_command) }.to raise_error(Beefcake::Message::RequiredFieldNotSetError)
  #   end
  # end

  # context "Agent Lifecycle Encoder" do
  #   let(:message1) { {:state => "running", :name => 'NullAgent', :pid => 3465, :monitor => 'false', :singleton => 'true', :started_at => Time.now.utc.to_i} }

  #   it "should encode and decode a correct message when the message type is specified as a symbol" do
  #     Smith::ACL::Payload.decode(Smith::ACL::Payload.new(:agent_lifecycle).content(message1).encode, :agent_lifecycle).should == message1
  #   end
  # end
end
