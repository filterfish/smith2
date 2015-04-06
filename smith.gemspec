Kernel.load './lib/smith/version.rb'

Gem::Specification.new do |s|
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
  s.licenses = ['GPL-3']
  s.add_runtime_dependency 'oj', '~> 2.11', '~> 2.11.4'
  s.add_runtime_dependency 'amqp', '~> 1.0', '~> 1.5'
  s.add_runtime_dependency 'daemons', '~> 1.1'
  s.add_runtime_dependency "eventmachine", "~> 1.0"
  s.add_runtime_dependency "extlib", "0.9.16"
  s.add_runtime_dependency "logging", "~> 1.8"
  s.add_runtime_dependency 'protobuf', '~> 3.4'
  s.add_runtime_dependency "state_machine", "1.1.2"
  s.add_runtime_dependency "trollop", "~> 2.0"
  s.add_runtime_dependency "multi_json", "~> 1.10"
  s.add_runtime_dependency "ruby_parser", "~> 3.6"
  s.add_runtime_dependency "murmurhash3", "0.1.4"
  s.add_runtime_dependency "curses", "1.0.1"
  s.add_runtime_dependency "toml-rb", "~> 0.3"

  binaries = %w{agency smithctl pry-smith}
  libraries = `git ls-files lib`.split(/\n/)
  config = %w{config/smithrc.toml}

  s.executables = binaries

  s.files = binaries.map { |b| "bin/#{b}" } + libraries + config
end
