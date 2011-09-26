# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgentKeepalive
        include Beefcake::Message

        required :name, :string, 1
        optional :pid, :string, 2
        optional :time, :string, 3
      end
    end
  end
end
