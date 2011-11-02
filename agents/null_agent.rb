# -*- encoding: utf-8 -*-
class NullAgent < Smith::Agent

  options :monitor => false

  task do |payload|
    logger.debug payload
  end
end
