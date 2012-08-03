require 'pp'

module Smith
  module ObjectCount
    def object_count(threshold=10)
      objects = ObjectSpace.each_object.inject(Hash.new(0)) do |a,o|
        a.tap {|acc| acc[o.class.to_s] += 1}
      end.sort {|(_,a),(_,b)| b <=> a}

      max_table_width = objects.first[1].to_s.length + 3

      objects.inject([]) do |a,(clazz,count)|
        a.tap {|acc| acc << "%-#{max_table_width}s%s" % [count,clazz] if count > threshold}
      end
    end
  end
end
