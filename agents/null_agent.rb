# -*- encoding: utf-8 -*-
class NullAgent < Smith::Agent

  task do |payload|
    logger.debug payload
  end
end
