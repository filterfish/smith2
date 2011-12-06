# -*- encoding: utf-8 -*-
require 'pp'
require 'state_machine'
require 'dm-observer'

module Smith
  class ProtocolBufferCompiler

    include Logger

    def initialize(force=false)
      @output_path = Smith.pb_cache_path
      @command = "protoc --beefcake_out #{@output_path.realpath} -I%s %s"
    end

    def compile
      # Invoke protoc once per path item. This makes error reporting easier.
      Smith.pb_path.each do |path|
        results = {}
        path_glob(path) do |p|
          if should_compile?(p)
            logger.info("Compiling: #{p} into #{@output_path}")
            results[p.to_s] = `#{@command % [path.realpath, p]}`
          end
        end

        #pp results
        #logger.info(compiler_output)
      end
      @output_path
    end

    # Clears the Protocol Buffer cache. If protocol_buffer_cache_path si
    # specified in the config then the directory itself won't be removed
    # but if it's not specified and a temporary directory was created then
    # the directory is removed as well.
    def clear_cache
      logger.info("Clearing the Protocol Buffer cache: #{Smith.pb_cache_path}")

      Pathname.glob(@output_path.join("*")).each do |path|
        path.unlink
      end

      unless Smith.config.agency._has_key?(:protocol_buffer_cache_path)
        @output_path.rmdir
      end
    end

    private

    # Returns true if the .proto file is newer that the .pb.rb file
    def should_compile?(file)
      cached_file = @output_path.join(file.basename).sub_ext(".pb.rb")
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
      Pathname.glob("#{path.join("*.proto")}").map do |pb|
        yield pb.realpath
      end
    end
  end
end
