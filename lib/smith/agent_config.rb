# -*- encoding: utf-8 -*-

require 'leveldb'
require 'pathname'

module Smith
  class AgentConfig

    def initialize(path, name)
      @path = Pathname.new(path)
      @db ||= LevelDB::DB.new(@path.join(name).to_s)
    end

    def for(agent)
      @db[agent]
    end

    def update(agent, value)
      @db[agent] = value
    end
  end
end
