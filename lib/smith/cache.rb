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

    def entries
      @cache.keys.map(&:to_s)
    end

    def invalidate(name)
      @cache.delete(name)
    end

    def select
      # This seems wierd. TODO verify that this is best way to do this.
      @cache.select { |k,v| yield v }.map { |k,v| v }
    end

    def map
      if block_given?
        @cache.map { |k,v| yield v }
      else
        @cache.map { |k,v| v }
      end
    end

    def each
      if block_given?
        @cache.each_value { |v| yield v }
      else
        @cache.each_value
      end
    end

    def empty?
      @cache.empty?
    end

    def size
      @cache.size
    end

    protected

    def update(name, entry)
      @cache[name] = entry
    end
  end
end
