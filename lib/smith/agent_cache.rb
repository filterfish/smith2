# -*- encoding: utf-8 -*-
require 'leveldb'
require 'letters'

module Smith
  class AgentCache < Cache

    attr_accessor :path

    def initialize(opts={})
      super()
      @db = LevelDB::DB.make(Smith.cache_path.join('agent_state').to_s, :error_if_exists => false, :create_if_missing => true)
      @paths = opts[:paths]

      operator ->(agent_name, options={}) { @db[agent_name] || AgentProcess.new(@db, :name => agent_name, :path => agent_path(agent_name)) }
      populate
    end

    def alive?(name)
      (exist?(name)) ? entry(name).alive? : false
    end

    def state(state)
      select {|a| a.state == state.to_s }
    end

    def delete(agent_name)
      @db.delete(agent_name)
      super
    end

    alias names :entries
    alias :[] :entry

    private

    # When we start load any new data from the db.
    def populate
      @db.values.map do |s|
        ap = AgentProcess.new(@db, s)
        update(ap.name, ap)
      end
    end

    def agent_path(agent_name)
      @paths.detect { |path| Pathname.new(path).join("#{agent_name.snake_case}.rb").exist? }.to_s
    end
  end
end
