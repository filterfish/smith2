# -*- encoding: utf-8 -*-
module Smith
  module Messaging
    class IncompletePayload < RuntimeError; end
    class IncorrectPayloadType < RuntimeError; end
  end
end
