# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    module Encoder
      class AgencyCommand
        include Beefcake::Message

        required :command, :string, 1
        repeated :target, :string, 2, :packed => true
        repeated :options, :string, 3
      end
    end
  end
end
