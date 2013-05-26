# -*- encoding: utf-8 -*-
require 'tdb'
require 'securerandom'

module Smith
  class AgentCache

    include Enumerable

    attr_accessor :path

    def initialize(opts={})
      # @db = LevelDB::DB.make(Smith.cache_path.join('agent_state').to_s, :error_if_exists => false, :create_if_missing => true)
      @db = TDB.new(Smith.cache_path.join('agent_state.tdb').to_s)
    end

    def create(name)
      AgentProcess.new(@db, :name => name, :uuid => SecureRandom.uuid)
    end

    def alive?(uuid)
      (@db.include?(uuid)) ? instantiate(@db[uuid]).alive? : false
    end

    def exist?(uuid)
      @db.include?(uuid)
    end

    def find_by_name(*names)
      inject([]) do |a, agent|
        a.tap do |acc|
          names.flatten.each do |name|
            acc << agent if name == agent.name
          end
        end
      end
    end

      # select {|a| a.name == name.to_s }
    # end

    def state(state)
      select {|a| a.state == state.to_s }
    end

    def delete(uuid)
      @db.delete(uuid)
    end

    def entry(uuid)
      (uuid) ? instantiate(@db[uuid]) : nil
    end

    alias :[] :entry

    def each(&blk)
      @db.each {|k,v| blk.call(instantiate(v)) }
    end

    private

    def instantiate(state)
      (state) ? AgentProcess.new(@db, state) : nil
    end
  end
end
