# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgentLifecycle
        include Beefcake::Message

        required :state, :string, 1
        required :name, :string, 2
        optional :pid, :string, 3
        optional :monitor, :bool, 4
        optional :singleton, :bool, 5
        optional :started_at, :string, 6
      end
    end
  end
end
