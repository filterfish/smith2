#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'smith/commands/common'

module Smith
  module Commands
    class CUT
      include Common
    end
  end
end

describe Smith::Commands::Common do

  # This is shit test as it relies on the correct agents being symlinked
  # in the agents group directory
  it 'list all agents in a group' do
    cut = Smith::Commands::CUT.new
    expect(cut.agent_group('group').sort).to eq(["Namespaced::Foo::NamespacedAgent", 'Namespaced::FooAgent'])
  end
end
