module Smith
  class AgentCache < Cache

    def initialize
      super()
      operator ->(agent_name){AgentProcess.first(:name => agent_name) || AgentProcess.new(:name => agent_name)}
    end

    def state(state)
      select {|a| a.state == state.to_s }
    end

    def names
      entries
    end

    alias :[] :entry
  end
end
