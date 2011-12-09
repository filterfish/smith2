# -*- encoding: utf-8 -*-
module Smith
  module ACL
    class AgencyCommand
      include Beefcake::Message

      required :command, :string, 1
      repeated :args, :string, 2, :packed => true
    end
  end
end
