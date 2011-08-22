# -*- encoding: utf-8 -*-
module Smith
  module Encoder
    def encode(message)
      Marshal.dump({:message => message})
    end

    def decode(message)
      Marshal.load(message)[:message]
    end
  end
end
