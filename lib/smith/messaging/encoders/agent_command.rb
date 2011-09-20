# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgentCommand
        include Beefcake::Message

        required :command, :string, 1
        repeated :options, :string, 2
      end
    end
  end
end
