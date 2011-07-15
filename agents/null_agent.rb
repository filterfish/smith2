class NullAgent < Smith::Agent

  def initialize(opts={})
    super(opts.merge(:monitor => true))
  end

  def run
    get_message(:test) do |header,message|
      logger.info(message)
    end
  end
end
