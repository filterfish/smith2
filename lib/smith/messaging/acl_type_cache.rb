# -*- encoding: utf-8 -*-

require 'set'
require 'singleton'
require 'murmurhash3'

module Smith
  class AclTypeCache
    include Singleton
    include MurmurHash3

    SUPPORTED_FORMATS = [:string, :binary]
    DEFAULT_FORMAT = :string

    def initialize
      clear!
    end

    # Add the type to the cashe. This will add the type for all know formats
    # @param type [Class] the type to add
    # @return [true|false] true if the type was added or false if it already exists.
    def add(type)
      if SUPPORTED_FORMATS.all? { |format| @types[format].has_key?(type) }
        false
      else
        SUPPORTED_FORMATS.each do |format|
          h = to_murmur32(type, format)
          @types[format][type] = h
          @hashes[format][h] = type
        end

        # TODO: would Inflecto::demodulize work here instead?
        @legacy_types_by_hash[Inflecto.underscore(type.to_s.split(/::/)[-1])] = type
        true
      end
    end

    # Return the type given the mumur3 hash
    # @param type [Sting] the mumur3 hash to lookup
    # @param format [Symbol] the format of the mumor3 hash. Defaults to
    #   Smith::AclTypeCache::DEFAULT_FORMAT
    # @return [Class]
    # @raise [Smith::ACL::UnknownError] raised when an unknown ACL is given
    def get_by_hash(type, format=DEFAULT_FORMAT)
      if t = dump_hashes(format)[type]
        t
      else
        if t = @legacy_types_by_hash[type.to_s]
          t
        else
          raise ACL::UnknownError, "Unknown ACL: #{t}"
        end
      end
    end

    # Return the mumur3 hash of the given the type
    # @param type [Class] the class to lookup
    # @param format [Symbol] the format of the mumor3 hash. Defaults to
    #   Smith::AclTypeCache::DEFAULT_FORMAT
    # @return [String]
    def get_by_type(type, format=DEFAULT_FORMAT)
      dump_types(format)[type].tap { |t| raise ACL::UnknownError, "Unknown ACL: #{t}" if type.nil? }
    end

    # Look the key up in the cache. This defaults to the key being the hash.
    # If :by_type => true is passed in as the second argument then it will
    # perform the lookup in the type hash.
    def include?(key, opts={})
      if opts[:by_type]
        !get_by_type(key, opts.fetch(:format, DEFAULT_FORMAT)).nil?
      else
        !get_by_hash(key, opts.fetch(:format, DEFAULT_FORMAT)).nil?
      end
    end

    # Clear the internal hashes.
    def clear!
      @types = SUPPORTED_FORMATS.each_with_object({}) { |v, acc| acc[v] = {} }
      @hashes = SUPPORTED_FORMATS.each_with_object({}) { |v, acc| acc[v] = {} }
      @legacy_types_by_hash = {}
    end

    # Dump the type hash
    # @param format [Symbol] the format of the mumor3 hash. Defaults to
    #   Smith::AclTypeCache::DEFAULT_FORMAT
    # @return [Hash]
    # @raise [Smith::ACL::UnknownTypeFormat] raised when an unknown format is given
    def dump_types(format=DEFAULT_FORMAT)
      if @types.has_key?(format)
        @types[format]
      else
        raise ACL::UnknownTypeFormat, "Uknown format: #{format}"
      end
    end

    # Dump the hashes hash
    # @param format [Symbol] the format of the mumor3 hash. Defaults to
    #   Smith::AclTypeCache::DEFAULT_FORMAT
    # @return [Hash]
    # @raise [Smith::ACL::UnknownTypeFormat] raised when an unknown format is given
    def dump_hashes(format=DEFAULT_FORMAT)
      if @hashes.has_key?(format)
        @hashes[format]
      else
        raise ACL::UnknownTypeFormat, "Uknown format: #{format}"
      end
    end

    private

    # Convert the type to a murmor3 hash
    # @param type [Class] the class to lookup
    # @param format [Symbol] the format of the mumor3 hash. Defaults to
    #   Smith::AclTypeCache::DEFAULT_FORMAT
    # @return [String]
    # @raise [Smith::ACL::UnknownTypeFormat] raised when an unknown format is given
    def to_murmur32(type, format)
      case format
      when :string
        MurmurHash3::V32.murmur3_32_str_hash(type.to_s).to_s(36)
      when :binary
        MurmurHash3::V32.murmur3_32_str_hash(type.to_s)
      else
        raise ACL::UnknownTypeFormat, "Uknown format: #{format}"
      end
    end
  end
end
