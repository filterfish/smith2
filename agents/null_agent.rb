class NullAgent < Smith::Agent

  def initialize(opts={})
    super(opts.merge(:monitor => false))
  end

  task do |payload|
    logger.info(payload)
  end
end
