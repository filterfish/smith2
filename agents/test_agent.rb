# -*- encoding: utf-8 -*-
class TestAgent < Smith::Agent
  task(:threads => true) do |payload|
    logger.debug payload
  end
end
