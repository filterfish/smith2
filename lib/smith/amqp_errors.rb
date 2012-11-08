# -*- encoding: utf-8 -*-

module Smith
  module Messaging
    module AmqpErrors

      private

      def error_message(code, text, &blk)
        details = error_lookup(code)
        message = "#{details[:error_class]} exception: #{code} (#{details[:name]}). #{details[:description]}"

        case code
        when 404
          diagnosis = "looks like the queue has been deleted."
        when 406
          case text
          when /.*(unknown delivery tag [0-9]+).*/
            diagnosis = "#{$1} - you've probably already acknowledged the message."
          end
        else
        end
        blk.call(message, diagnosis)
      end

      def error_lookup(code)
        errors[code]
      end

      def errors
        @errors ||= {
          311 => {:name => "content-too-large", :error_class => "Channel", :description => "The client attempted to transfer content larger than the server could accept at the present time. The client may retry at a later time."},
          313 => {:name => "no-consumers", :error_class => "Channel", :description => "When the exchange cannot deliver to a consumer when the immediate flag is set. As a result of pending data on the queue or the absence of any consumers of the queue."},
          320 => {:name => "connection-forced", :error_class => "Connection", :description => "An operator intervened to close the Connection for some reason. The client may retry at some later date."},
          402 => {:name => "invalid-path", :error_class => "Connection", :description => "The client tried to work with an unknown virtual host."},
          403 => {:name => "access-refused", :error_class => "Channel", :description => "The client attempted to work with a server entity to which it has no access due to security settings."},
          404 => {:name => "not-found", :error_class => "Channel", :description => "The client attempted to work with a server entity that does not exist."},
          405 => {:name => "resource-locked", :error_class => "Channel", :description => "The client attempted to work with a server entity to which it has no access because another client is working with it."},
          406 => {:name => "precondition-failed", :error_class => "Channel", :description => "The client requested a method that was not allowed because some precondition failed."},
          501 => {:name => "frame-error", :error_class => "Connection", :description => "The sender sent a malformed frame that the recipient could not decode. This strongly implies a programming error in the sending peer."},
          502 => {:name => "syntax-error", :error_class => "Connection", :description => "The sender sent a frame that contained illegal values for one or more fields. This strongly implies a programming error in the sending peer."},
          503 => {:name => "command-invalid", :error_class => "Connection", :description => "The client sent an invalid sequence of frames, attempting to perform an operation that was considered invalid by the server. This usually implies a programming error in the client."},
          504 => {:name => "channel-error", :error_class => "Connection", :description => "The client attempted to work with a Channel that had not been correctly opened. This most likely indicates a fault in the client layer."},
          505 => {:name => "unexpected-frame", :error_class => "Connection", :description => "The peer sent a frame that was not expected, usually in the context of a content header and body. This strongly indicates a fault in the peer's content processing."},
          506 => {:name => "resource-error", :error_class => "Connection", :description => "The server could not complete the method because it lacked sufficient resources. This may be due to the client creating too many of some type of entity."},
          530 => {:name => "not-allowed", :error_class => "Connection", :description => "The client tried to work with some entity in a manner that is prohibited by the server, due to security settings or by some other criteria."},
          540 => {:name => "not-implemented", :error_class => "Connection", :description => "The client tried to use functionality that is not implemented in the server."},
          541 => {:name => "internal-error", :error_class => "Connection", :description => "The server could not complete the method because of an internal error. The server may require intervention by an operator in order to resume normal operations."}
        }
      end
    end
    end
  end
