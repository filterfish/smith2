# -*- encoding: utf-8 -*-

require 'pathname'
require 'spec_helper'
require 'config'

describe Smith::Config do

  before(:all) do
    @tmp_dir = Pathname.new(`mktemp -d`.strip)
    @cwd = Pathname.pwd
    @root = Pathname.new(__FILE__).parent.parent
    FileUtils.copy_file(@root.join('config', 'smithrc'), @tmp_dir.join('.smithrc'))
    FileUtils.copy_file(@root.join('config', 'smithrc.with.amqp'), @tmp_dir.join('smithrc.with.amqp'))
    Dir.chdir(@tmp_dir)
  end

  after(:all) do
    Dir.chdir(@cwd)
    @tmp_dir.rmtree
  end

  context "General" do

    before(:each) do
      FileUtils.copy_file(@root.join('config', 'smithrc'), @tmp_dir.join('.smithrc'))
    end

    let(:config) { Smith::Config.new }

    it "Config file Path" do
      expect(config.path).to eq(@tmp_dir.join('.smithrc'))
    end

    it "Reload with default file." do
      expect(config.smith.timeout).to eq(4)

      FileUtils.copy_file(@root.join('config', 'smithrc.1'), @tmp_dir.join('.smithrc'))
      config.reload
      expect(config.smith.timeout).to eq(5)
    end

    it "Reload with named file." do
      FileUtils.copy_file(@root.join('config', 'smithrc'), @tmp_dir.join('.smithrc.named'))
      config = Smith::Config.new('.smithrc.named')

      expect(config.smith.timeout).to eq(4)

      FileUtils.copy_file(@root.join('config', 'smithrc.1'), @tmp_dir.join('.smithrc.named'))
      config.reload
      expect(config.smith.timeout).to eq(5)
    end

  end

  context "Default config file" do

    before(:each) do
      FileUtils.copy_file(@root.join('config', 'smithrc'), @tmp_dir.join('.smithrc'))
    end

    let(:config) { Smith::Config.new }

    it "raise an exception if the config can't be found" do
      expect do
        Smith::Config.new("smithrc.nonexistent")
      end.to raise_error(Smith::ConfigNotFoundError)
    end

    it 'agent' do
      agent = config.agent
      expect(config.agent.monitor).to eq(false)
      expect(config.agent.singleton).to eq(true)
      expect(config.agent.metadata).to eq("")
      expect(config.agent.prefetch).to eq(2)
    end

    it 'smith' do
      expect(config.smith.namespace).to eq('smith')
      expect(config.smith.timeout).to eq(4)
    end

    it 'eventmachine' do
      expect(config.eventmachine.epoll).to eq(true)
      expect(config.eventmachine.kqueue).to eq(false)
      expect(config.eventmachine.file_descriptors).to eq(1024)
    end

    it 'amqp default' do
      expect(config.amqp.exchange).to eq({:durable => true, :auto_delete => false})
      expect(config.amqp.queue).to eq(:durable => true, :auto_delete => false)
      expect(config.amqp.publish).to eq(:headers => {})
      expect(config.amqp.subscribe).to eq(:ack => true)
      expect(config.amqp.pop).to eq({:ack => true})
    end

    it 'amqp overriden' do
      config = Smith::Config.new('smithrc.with.amqp')
      expect(config.amqp.exchange).to eq({:durable => true, :auto_delete => false})
      expect(config.amqp.queue).to eq(:durable => true, :auto_delete => false)
      expect(config.amqp.publish).to eq(:headers => {})
      expect(config.amqp.subscribe).to eq(:ack => false)
      expect(config.amqp.pop).to eq({:ack => false})
    end

    it 'amqp.broker' do
      expect(config.amqp.broker.host).to eq("localhost")
      expect(config.amqp.broker.port).to eq(5672)
      expect(config.amqp.broker.user).to eq("guest")
      expect(config.amqp.broker.password).to eq("guest")
      expect(config.amqp.broker.vhost).to eq("/")
    end

    it 'vm' do
      expect(config.vm.agent_default).to eq('/usr/local/ruby-2.1.0/bin/ruby')
      expect(config.vm.null_agent).to eq('/usr/local/ruby-2.1.1/bin/ruby')
    end

    it 'agency' do
      expect(config.agency.pid_dir).to eq(Pathname.new("/run/smith"))
      expect(config.agency.cache_path).to eq(Pathname.new("/var/cache/smith/lmdb"))
      expect(config.agency.agent_path).to eq(Pathname.new("/home/rgh/dev/ruby/smith2/agents"))
      expect(config.agency.acl_path).to eq(Pathname.new("/home/rgh/dev/ruby/smith2/lib/acl"))
    end

    it 'logging' do
      expect(config.logging.trace).to eq(true)
      expect(config.logging.level).to eq('verbose')
    end

    it 'appender' do
      expect(config.logging.appender.filename).to eq("/var/log/smith/smith.log")
      expect(config.logging.appender.type).to eq("RollingFile")
      expect(config.logging.appender.age).to eq("daily")
      expect(config.logging.appender.keep).to eq(100)
    end
  end

  context "Load using class method" do

    it "Default file" do
      config = Smith::Config.get
      expect(config.path).to eq(@tmp_dir.join('.smithrc'))
      expect(config.smith.timeout).to eq(4)
    end
  end
end
