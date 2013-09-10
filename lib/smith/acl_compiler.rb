# -*- encoding: utf-8 -*-
require 'ffi'
require "tempfile"
require 'ruby_parser'
require 'smith/messaging/acl_type_cache'

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
      logger.fatal { "Cannot load protobuf shared library: #{e}" }
      exit(1)
    end

    attach_function(:_rprotoc_extern, [:int, :pointer], :int32)

    def initialize
      @acl_type_cache = AclTypeCache.instance
      @acl_parser = ACLParser.new
    end

    def compile
      Smith.acl_path.each do |path|
        acls_files = path_glob(path)
        out_of_date_acls = path_glob(path).select { |p| should_compile?(p) }
        if out_of_date_acls.size > 0
          compile_on_path(path, acls_files, out_of_date_acls)
        end

        acls_files.each do |acl_file|
          acl_class_path = acl_compiled_path(acl_file)
          load_acl(acl_class_path)
          add_to_type_cache(acl_class_path)
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
      Pathname.glob(path.join("*.proto")).map { |acl| acl.realpath }
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

    def load_acl(path)
      logger.verbose { "Loading ACL: #{path}" }
      require path
    end

    def add_to_type_cache(path)
      acl_class = File.read(path)
      @acl_parser.go(acl_class)
      @acl_parser.fully_qualified_classes.each do |clazz|
        @acl_type_cache.add(to_class(clazz))
      end
    end

    def to_class(type_as_array)
      type_as_array.inject(Kernel) { |acc, t| acc.const_get(t) }
    end

    def acl_compiled_path(path)
      "#{Smith.acl_cache_path.join(path.basename('.proto'))}.pb.rb"
    end
  end
end
