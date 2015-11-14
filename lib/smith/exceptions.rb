# -*- encoding: utf-8 -*-
module Smith
  class UnknownEnvironmentError < RuntimeError
    def initialize(message=nil)
      super("Invalid environment: #{message || Smith.environment}")
    end
  end

  class AgencyRunning < RuntimeError; end

  module Messaging
    class MessageTimeoutError < RuntimeError; end
  end

  module ACL
    class Error < RuntimeError; end
    class IncorrectTypeError < Error; end
    class UnknownError < Error; end
    class UnknownTypeFormat < Error; end
  end
end
