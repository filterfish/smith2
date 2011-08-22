# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent

  task do |payload|
    logger.debug payload
  end
end
