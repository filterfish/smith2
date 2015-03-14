# -*- encoding: utf-8 -*-

require 'extlib/string'

module Smith
  module Commands
    class Acl < CommandBase
      def execute
        responder.succeed(_acl)
      end

      def _acl
        acl_type_cache = AclTypeCache.instance
        if options[:show]
          if target.empty?
            "You must supply an ACL file name."
          else
            target.map do |acl|
              if options[:source_given]
                acls = find_acl(Smith.acl_cache_directory, acl, 'pb.rb')
              else
                acls = find_acl(Smith.acl_directories, acl, 'proto')
              end

              case acls.length
              when 0
                "ACL file does not exist."
              when 1
                if target.length == 1
                  "\n#{indent_acl(acls.first.read)}\n"
                else
                  "\n#{acl} ->\n#{indent_acl(acls.first.read)}"
                end
              else
                "There are multiple ACLs with the name: #{target}"
              end
            end.join("\n")
          end
        elsif options[:clean_given]
          Pathname.glob(Smith.acl_cache_directory.join("*.pb.rb")).each {|p| p.unlink}
          ""
        elsif options[:compile_given]
          Pathname.glob(Smith.compile_acls)
          ""
        else
          join_string = (options[:long]) ? "\n" : " "
          acl_type_cache.dump_types.keys.map(&:to_s).sort.join(join_string)

          # Pathname.glob(Smith.acl_directories.map {|p| "#{p}#{File::SEPARATOR}*"}).map do |p|
          #   p.basename(".proto")
          # end.sort.join(join_string)
        end
      end

      private

      def find_acl(directories, acl, ext)
        [directories].flatten.inject([]) do |a, directory|
          a.tap do |acc|
            acl_file =  directory.join("#{acl.snake_case}.#{ext}")
            acc << acl_file if acl_file.exist?
          end
        end
      end

      def indent_acl(acl)
        acl.split("\n").map { |l| l.sub(/^/, "  ") }.join("\n")
      end

      def options_spec
        banner "List and display acl files."

        opt    :long,     "format the listing", :short => :l
        opt    :show,     "show the contents of the acl file", :short => :s
        opt    :source,   "show the contents of the generated acl file", :depends => :show
        opt    :clean,    "remove all compiled acls", :short => :none
        opt    :compile,  "compile all acls", :short => :none
      end
    end
  end
end
