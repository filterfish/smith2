class TestAgent < Smith::Agent

  task do |payload|
    logger.debug payload
  end
end
