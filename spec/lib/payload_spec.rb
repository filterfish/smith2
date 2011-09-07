# -*- encoding: utf-8 -*-

require 'spec_helper'

describe Smith::Messaging::Payload do

  include Smith::Messaging

  before(:all) do
    @message = "This is a message using the default encoder"
  end

  context "Default Encoder" do
    it 'should encode a message' do
      Marshal.load(Payload.new(@message).encode).should == @message
    end

    it "should decode a message using the default encoder" do
      Payload.decode(Marshal.dump(@message)).should == @message
    end
  end

  context "Command Encoder" do
    let(:message1) { {:command => "list"} }
    let(:message2) { {:command => "list", :options => ["--all", "--l"]} }
    let(:message3) { {:command => :list} }
    let(:message4) { {:incorrect_command => 'list'} }

    it "should encode and decode a correct message" do
      Payload.decode(Payload.new(message1, :command).encode, :command).should == message1
      Payload.decode(Payload.new(message2, :command).encode, :command).should == message2
    end

    it "should throw an TypeException when an message of incorect type is used" do
      expect { Payload.decode(Payload.new(message3, :command).encode, :command) }.to raise_error(TypeError)
    end

    it "should throw an RequiredFieldNotSetError when a message with an incorrect field is used" do
      expect { Payload.decode(Payload.new(message4, :command).encode, :command) }.to raise_error(Beefcake::Message::RequiredFieldNotSetError)
    end
  end
end
