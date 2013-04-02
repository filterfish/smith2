# -*- encoding: utf-8 -*-

require 'set'
require 'singleton'
require 'murmurhash3'

module Smith
  class AclTypeCache
    include Singleton
    include MurmurHash3

    def initialize
      clear!
    end

    def add(type)
      if @types[type]
        false
      else
        h = to_murmur32(type)
        @types[type] = h
        @hashes[h] = type
        true
      end
    end

    def get_by_hash(type)
      @hashes[type]
    end

    def get_by_type(type)
      @types[type]
    end

    # Look the key up in the cache. This defaults to the key being the hash.
    # If :by_type => true is passed in as the second argument then it will
    # perform the lookup in the type hash.
    # 
    def include?(key, opts={})
      if opts[:by_type]
        !get_by_type(key).nil?
      else
        !get_by_hash(key).nil?
      end
    end

    # Clear the internal hashes.
    def clear!
      @types = {}
      @hashes = {}
    end

    # Dump the type hash
    def dump_types
      @types
    end

    # Dump the hashes hash
    def dump_hashes
      @hashes
    end

    private

    # Convert the name to a base 36 murmur hash
    def to_murmur32(type)
      V32.murmur3_32_str_hash(type.to_s).to_s(36)
    end
  end
end
