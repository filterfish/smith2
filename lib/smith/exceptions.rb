# -*- encoding: utf-8 -*-
module Smith
  class UnknownEnvironmentError < RuntimeError
    def initialize(message=nil)
      super("Invalid environment: #{message || Smith.environment}")
    end
  end

  module Messaging
    class IncompletePayload < RuntimeError; end
    class IncorrectPayloadType < RuntimeError; end
  end
end
