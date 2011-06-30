require 'pp'
require 'state_machine'
require 'dm-core'
require 'dm-yaml-adapter'

class AgentState

  include DataMapper::Resource

  property :id,         Serial
  property :name,       String, :required => true
  property :state,      String, :required => true
  property :pid,        Integer
  property :name,       String
  property :started_at, Time
  property :restart,    Boolean
  property :singleton,  Boolean

  state_machine :initial => :stopped do
    event :start do
      transition [:stopped] => :starting
    end

    event :acknowledge_start do
      transition [:starting] => :running
    end

    event :stop do
      transition [:running] => :stopping
    end

    event :acknowledge_stop do
      transition [:stopping] => :stopped
    end

    event :not_responding do
      transition [:starting, :running, :stopping] => :unkown
    end

    event :no_process_running do
      transition [:running] => :dead
    end

    state :starting do
      def bar
        puts :starting
      end
    end
  end
end
