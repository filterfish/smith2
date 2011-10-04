# -*- encoding: utf-8 -*-
module Smith
  class AgentCache < Cache

    attr_accessor :path

    def initialize(opts={})
      super()
      @paths = opts[:paths]
      operator ->(agent_name){AgentProcess.first(:name => agent_name) || AgentProcess.new(:name => agent_name, :path => agent_path(agent_name))}
      populate
    end

    def alive?(name)
      (exist?(name)) ? entry(name).alive? : false
    end

    def state(state)
      select {|a| a.state == state.to_s }
    end

    alias names :entries
    alias :[] :entry

    private

    # When we start load any new data from the db.
    def populate
      AgentProcess.all.each { |a| update(a.name, a) }
    end

    def agent_path(agent_name)
      @paths.detect do |path|
        Pathname.new(path).join("#{agent_name.snake_case}.rb").exist?
      end
    end
  end
end
