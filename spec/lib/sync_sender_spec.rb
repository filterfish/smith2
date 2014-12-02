# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'smith/messaging/sync_sender'

class DummyMessage < ::Protobuf::Message
  required ::Protobuf::Field::StringField, :message, 1
end

describe Smith::Messaging::SyncSender do
  let(:sender) { Smith::Messaging::SyncSender.new("some_queue") }

  describe '#publish' do
    it 'sends the message using bunny' do
      expect_any_instance_of(Bunny::Exchange).to receive(:publish) do |*args|
        expect(args[1]).to eq("\n\vhello world")
      end
      sender.publish(DummyMessage.new(:message => "hello world"))
    end
  end
end
