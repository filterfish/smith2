# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgentLifecycle
        include Beefcake::Message

        required :state, :string, 1
        required :name, :string, 2
        optional :pid, :string, 3
        optional :monitor, :string, 4
        optional :singleton, :string, 5
        optional :started_at, :string, 6
      end
    end
  end
end
