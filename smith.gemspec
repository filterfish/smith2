Kernel.load './lib/smith/version.rb'

spec = Gem::Specification.new do |s|
  s.name = 'smith'
  s.version = Smith::VERSION
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = 'Multi-agent framework'
  s.email = "rgh@filterfish.org"
  s.homepage = "http://github.com/filterfish/smith2"
  s.description = "Simple multi-agent framework. It uses AMQP for it's messaging layer."
  s.has_rdoc = false
  s.rubyforge_project = "smith"

  s.authors = ["Richard Heycock"]
  s.add_dependency "amqp", ">= 1.0.2"
  s.add_dependency "daemons", ">= 1.1.4"
  s.add_dependency "eventmachine", ">= 1.0.0"
  s.add_dependency "extlib", ">= 0.9.15"
  s.add_dependency "logging", ">= 1.6.1"
  s.add_dependency "protobuf", ">= 2.8.2"
  s.add_dependency "state_machine", "1.1.2"
  s.add_dependency "trollop", ">= 1.16.2"
  s.add_dependency "multi_json", ">= 1.3.2"
  s.add_dependency "ruby_parser", ">= 3.2.2"
  s.add_dependency "tdb"
  s.add_dependency "murmurhash3"

  binaries = %w{agency smithctl pry-smith}
  libraries = Dir.glob("lib/**/*")

  s.executables = binaries

  s.files = binaries.map { |b| "bin/#{b}" } + libraries
end
