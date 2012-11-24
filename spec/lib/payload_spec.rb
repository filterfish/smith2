# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'pp'

describe Smith::ACL::Payload do

  include Smith::ACL

  before(:all) do
    Smith.load_acls
    @message = {:message => "This is a message using the default encoder"}
    @acl = Smith::ACL::Factory.create(:default, @message)
  end

  context "New Payload" do
    it "should encode a message" do
      Smith::ACL::Payload.new(@acl).encode.should == "\x04\b{\x06:\fmessageI\"0This is a message using the default encoder\x06:\x06ET"
    end

    it "should decod a message" do
      Smith::ACL::Payload.decode("\x04\b{\x06:\fmessageI\"0This is a message using the default encoder\x06:\x06ET", :default).should == @message
    end
  end

  context "Default Encoder" do
    it 'should encode a message' do
      Marshal.load(Smith::ACL::Payload.new(@acl).encode).should == @message
    end

    it "should convert payload to a hash" do
      Smith::ACL::Payload.new(@acl).to_hash.should == @message
      Smith::ACL::Payload.decode(Marshal.dump(@acl)).to_hash.should == @message
    end

    it "should decode a message" do
      Smith::ACL::Payload.decode(Marshal.dump(@message)).should == @message
    end

    it "should decode a nil message" do
      Smith::ACL::Payload.decode(Marshal.dump(nil)).should == nil
    end
  end

  context "Agency Command Encoder" do
    let(:message1) { {:command => "list"} }
    let(:message2) { {:command => "list", :args => ["--all", "--l"]} }
    let(:message3) { {:command => :list} }
    let(:message4) { {:incorrect_command => 'list'} }

    it "should encode and decode a correct message when the message type is specified as a symbol" do
      acl1 = Smith::ACL::Factory.create(:agency_command, message1)
      acl2 = Smith::ACL::Factory.create(:agency_command, message2)

      Smith::ACL::Payload.decode(Smith::ACL::Payload.new(acl1).encode, :agency_command).to_hash.should == message1
      Smith::ACL::Payload.decode(Smith::ACL::Payload.new(acl2).encode, :agency_command).to_hash.should == message2
    end

    it "should encode and decode a correct message when the message type is specified as a class"
    # do
    #   acl = Smith::ACL::Factory.create(Smith::ACL::AgencyCommand, message1)
    #   acl.class.should = Smith::ACL::::AgencyCommand
    # end

    it "should access the decoded message fields using accessor methods." do
      acl = Smith::ACL::Factory.create(:agency_command, message2)
      decoded_message = Smith::ACL::Payload.decode(Smith::ACL::Payload.new(acl).encode, :agency_command)
      decoded_message.args.should == ["--all", "--l"]
    end
  end
end
