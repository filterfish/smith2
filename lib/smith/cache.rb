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

    def invalidate(name)
      @cache.delete(name)
    end

    def select
      @cache.select { |k,v| yield v }
    end

    def map
      @cache.map { |k,v| yield v }
    end

    def each
      @cache.each { |k,v| yield v }
    end
  end
end
