# -*- encoding: utf-8 -*-

require 'extlib/string'

module Smith
  module Commands
    class Acl < CommandBase
      def execute
        responder.succeed(_acl)
      end

      def _acl
        if options[:show]
          if target.empty?
            "You must supply an ACL file name."
          else
            target.map do |acl|
              if options[:source_given]
                acls = find_acl(Smith.acl_cache_path, acl, 'pb.rb')
              else
                acls = find_acl(Smith.acl_path, acl, 'proto')
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
          Pathname.glob(Smith.acl_cache_path.join("*.pb.rb")).each {|p| p.unlink}
          ""
        elsif options[:compile_given]
          Pathname.glob(Smith.compile_acls)
          ""
        else
          join_string = (options[:long]) ? "\n" : " "
          Pathname.glob(Smith.acl_path.map {|p| "#{p}#{File::SEPARATOR}*"}).map do |p|
            p.basename(".proto")
          end.sort.join(join_string)
        end
      end

      private

      def find_acl(path, acl, ext)
        [path].flatten.inject([]) do |a,path|
          a.tap do |acc|
            acl_file = path.join("#{acl.snake_case}.#{ext}")
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

        depends :source, :show
      end
    end
  end
end
