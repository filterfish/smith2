module Smith
  class Cache
    def initialize
      @cache = {}
    end

    def operator(operator)
      @operator = operator
    end

    def entry(name)
      if @cache[name]
        @cache[name]
      else
        @cache[name] = @operator.call(name)
      end
    end

    def each
      @cache.each do |k,v|
        yield v
      end
    end
  end
end
