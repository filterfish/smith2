# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgencyCommand
        include Beefcake::Message

        required :command, :string, 1
        repeated :args, :string, 2, :packed => true
      end
    end
  end
end
