spec = Gem::Specification.new do |s|
  s.name = 'smith2'
  s.version = '0.5'
  s.date = '2012-01-23'
  s.summary = 'Multi-agent framework'
  s.email = "rgh@filterfish.org"
  s.homepage = "http://github.com/filterfish/smith2/"
  s.description = "Simple multi-agent framework. It uses AMQP for it's messaging layer."
  s.has_rdoc = false
  s.rubyforge_project = "nowarning"

  s.authors = ["Richard Heycock"]
  s.add_dependency "amqp", "0.9.0"
  s.add_dependency "eventmachine", ">= 1.0.0.beta.4"
  s.add_dependency "ruby_protobuf", "= 0.4.11"
  s.add_dependency "logging"
  s.add_dependency "dm-core"
  s.add_dependency "dm-observer"
  s.add_dependency "dm-yaml-adapter"
  s.add_dependency "daemons", ">= 1.1.4"
  s.add_dependency "trollop", ">= 1.16.0"
  s.add_dependency "extlib"
  s.add_dependency "optimism", ">= 3.0.3"
  s.add_dependency "state_machine"

  binaries = %w{agency smithctl smith-cat}
  libraries = Dir.glob("lib/**/*")

  s.executables = binaries

  s.files = binaries.map { |b| "bin/#{b}" } + libraries
end
