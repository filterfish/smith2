# -*- encoding: utf-8 -*-
require 'pp'
require 'protobuf/compiler/compiler'

# There doesn't seem to be a way to turn of printing. The code is generally run
# like this: log_writing unless silent but there is no way of setting silent!
# So monkey patch it.
class Protobuf::Visitor::Base
  def log_writing(filename, message="writing..."); end
end

module Smith
  class ACLCompiler

    include Logger

    def initialize(force=false)
      # TODO Add the force code.
      @cache_path = Smith.acl_cache_path
    end

    # Compile any protocol buffer files. This checks the timestamp
    # to see if the file needs compiling.
    def compile
      fork do
        logger.debug { "Protocol buffer cache path: #{@cache_path}" }
        Smith.acl_path.each do |path|
          results = {}
          path_glob(path) do |p|
            if should_compile?(p)
              logger.info { "Compiling: #{p}" }
              # TODO put some error handling here.
              Protobuf::Compiler.compile(p.basename, p.dirname, @cache_path)
            end
          end
        end
      end
      @cache_path
    end

    def cache_path
      @cache_path.to_s
    end

    # Clears the Protocol Buffer cache. If acl_cache_path is
    # specified in the config then the directory itself won't be removed
    # but if it's not specified and a temporary directory was created then
    # the directory is removed as well.
    def clear_cache
      logger.info { "Clearing the Protocol Buffer cache: #{Smith.acl_cache_path}" }

      Pathname.glob(@cache_path.join("*")).each do |path|
        path.unlink
      end

      unless Smith.config.agency._has_key?(:acl_cache_path)
        @cache_path.rmdir
      end
    end

    private

    # Returns true if the .proto file is newer that the .pb.rb file
    def should_compile?(file)
      cached_file = @cache_path.join(file.basename).sub_ext(".pb.rb")
      if cached_file.exist?
        if file.mtime > cached_file.mtime
          true
        else
          false
        end
      else
        true
      end
    end

    def path_glob(path)
      Pathname.glob("#{path.join("*.proto")}").map do |acl|
        yield acl.realpath
      end
    end
  end
end
