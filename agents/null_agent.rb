class NullAgent < Smith::Agent

  def initialize(opts={})
    super(opts.merge(:monitor => true))
  end

  def default_handler(metadata, payload)
    logger.info(payload)
  end
end
