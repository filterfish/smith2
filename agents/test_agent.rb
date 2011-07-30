class TestAgent < Smith::Agent

  def initialize(opts={})
    super(opts.merge(:monitor => false))
  end

  def run
    listen(:test) do |header,message|
      logger.info(message)
    end
  end
end
