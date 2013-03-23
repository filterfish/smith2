# -*- encoding: utf-8 -*-
require 'ffi'
require "tempfile"

module Smith
  class ACLCompiler

    include Logger
    extend FFI::Library

    def self.find_so
      $:.map{|p| Pathname.new(p).join("ruby_generator.so")}.detect{|so| so.exist? }
    end

    begin
      ffi_lib(find_so)
    rescue LoadError => e
      logger.fatal { "Cannot load protobuf shared library." }
      exit(1)
    end

    attach_function(:_rprotoc_extern, [:int, :pointer], :int32)

    def compile
      Smith.acl_path.each do |path|
        acls = path_glob(path)
        out_of_date_acls = path_glob(path).select { |p| should_compile?(p) }
        if out_of_date_acls.size > 0
          compile_on_path(path, acls, out_of_date_acls)
        end
      end
    end

    private

    def compile_on_path(path, acls, out_of_date_acls)
      out_of_date_acls.each { |acl| logger.debug("Compiling acl: #{path.join(acl)}") }

      unless acls.empty?
        Dir.chdir(path) do
          begin
            GC.disable

            args = ["rprotoc", "--ruby_out", Smith.acl_cache_path, "--proto_path", path].map {|a| ::FFI::MemoryPointer.from_string(a.to_s.dup) }

            ffi_acls = acls.map do |acl|
              FFI::MemoryPointer.from_string(acl.to_s.dup)
            end
            ffi_acls << nil

            args += ffi_acls
            argv = FFI::MemoryPointer.new(:pointer, args.size)

            args.each_with_index { |p, index| argv[index].put_pointer(0, p) }

            errors = capture_stderr do
              self._rprotoc_extern(args.compact.size, argv)
            end.split("\n")

            errors.each do |error|
              logger.fatal { "Cannot compile ACLs: #{error}" }
              raise RuntimeError, error
            end
          ensure
            GC.enable
          end
        end
      end
    end

    # Returns true if the .proto file is newer that the .pb.rb file
    def should_compile?(file)
      cached_file = Smith.acl_cache_path.join(file.basename).sub_ext(".pb.rb")
      if cached_file.exist?
        file.mtime > cached_file.mtime
      else
        true
      end
    end

    def path_glob(path)
      Pathname.glob("#{path.join("*.proto")}").map { |acl| acl.realpath }
    end

    # This is not idea but I really don't know how else to do it. I cannot use
    # $stderr = StringIO.new as this only seems to capture STDERR if you
    # explicitly write to STDERR. In my case it's an ffi library call that's
    # writing to STDERR.
    def capture_stderr
      org_stderr = STDERR.dup
      begin
        tmp = Tempfile.new('')
        tmp.sync = true
        STDERR.reopen(tmp)
        yield
        File.read(tmp.path)
      ensure
        STDERR.reopen(org_stderr)
      end
    end
  end
end
