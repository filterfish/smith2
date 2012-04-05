spec = Gem::Specification.new do |s|
  s.name = 'smith2'
  s.version = File.read('./VERSION')
  s.date = '2012-02-22'
  s.summary = 'Multi-agent framework'
  s.email = "rgh@filterfish.org"
  s.homepage = "http://github.com/filterfish/smith2/"
  s.description = "Simple multi-agent framework. It uses AMQP for it's messaging layer."
  s.has_rdoc = false
  s.rubyforge_project = "nowarning"

  s.authors = ["Richard Heycock"]
  s.add_dependency "amqp", "0.9.0"
  s.add_dependency "dm-core", "1.0.1"
  s.add_dependency "dm-observer", "1.0.1"
  s.add_dependency "dm-yaml-adapter", "1.0.1"
  s.add_dependency "daemons", ">= 1.1.4"
  s.add_dependency "eventmachine", ">= 1.0.0.beta.4"
  s.add_dependency "extlib", ">= 0.9.15"
  s.add_dependency "logging", ">= 1.6.1"
  s.add_dependency "optimism", ">= 3.0.3"
  s.add_dependency "ruby_protobuf", "= 0.4.11"
  s.add_dependency "state_machine", "1.1.2"
  s.add_dependency "trollop", ">= 1.16.2"
  s.add_dependency "yajl-ruby", ">= 1.1.0"

  binaries = %w{agency smithctl}
  libraries = Dir.glob("lib/**/*")

  s.executables = binaries

  s.files = binaries.map { |b| "bin/#{b}" } + libraries
end
