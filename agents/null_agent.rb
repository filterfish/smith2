class NullAgent < Smith::Agent

  def initialize(opts={})
    super(opts.merge(:restart => true))
  end

  def run
    get_message(:test) do |header,message|
      Logger.info(message)
    end
  end
end
