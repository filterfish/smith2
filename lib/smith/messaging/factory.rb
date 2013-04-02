# -*- encoding: utf-8 -*-
module Smith

  module ACL
    class Factory
      include Logger

      class << self
        def create(type, content=nil, &blk)
          if type.respond_to?(:serialize_to_string)
            return type
          else
            clazz = (type.is_a?(::Protobuf::Message)) ? type : get_clazz(type)

            if blk
              clazz.new.tap { |m| blk.call(m) }
            else
              (content.nil?) ? clazz.new : clazz.new(content)
            end
          end
        end

        def get_clazz(type)
          type.to_s.split(/::/).inject(Kernel) { |acc, t| acc.const_get(t) }
        end
      end
    end
  end
end
