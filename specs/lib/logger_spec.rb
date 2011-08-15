# encoding: utf-8

# A few notes about this spec.
# 1. The helper that the logging gem supplies only works with rspec 1
#    and even when updated to work with rspec 2 it's too simplistic
#    for example it doesn't work with trace. Hence the code that captures
#    the stdout and uses that as the expectation.
# 2. I'm using send instead of invoking the method directly because the
#    methods are protected.

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

$pattern = "%5l - %c:%L - %m\n"

module Smith
  class ClassUnderTest
    include Smith::Logger

    log_pattern $pattern

    def self.capture_stdout(print_to_stdout=false)
      saved_stdout = STDOUT.dup
      tmp_file = Pathname.new(File.join(Dir.tmpdir, "rspec-logger#{$$}"))
      STDOUT.reopen(tmp_file)
      yield
      STDOUT.reopen(saved_stdout)
      tmp_file.open { |fd| fd.read }.tap do |output|
        puts output if print_to_stdout
        tmp_file.unlink
      end
    end
  end
end

describe Smith::Logger do
  # It scares me that I need to do this.
  # TODO work out if this is ok.
  before(:each) do
    Smith::ClassUnderTest.send(:log_level, :debug)
    Smith::ClassUnderTest.send(:log_trace, false)
  end

  context :basic do
    let(:cut) { Smith::ClassUnderTest.new }

    it 'should produce a log message when logger is invoked as a class method' do
      log_output = Smith::ClassUnderTest.capture_stdout do
        Smith::ClassUnderTest.send(:logger).debug("class log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest: - class log message\n"
    end

    it 'should produce a log message when logger is invoked as a instance method' do
      log_output = Smith::ClassUnderTest.capture_stdout do
        cut.send(:logger).debug("instance log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest: - instance log message\n"
    end

    it 'should set the trace level correctly logger is invoked as a class method' do
      Smith::ClassUnderTest.send(:log_trace, true)
      log_output = Smith::ClassUnderTest.capture_stdout do
        Smith::ClassUnderTest.send(:logger).debug("class log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest:63 - class log message\n"
    end

    it 'should set the trace level correctly logger is invoked as a instance method' do
      cut.send(:log_trace, true)
      log_output = Smith::ClassUnderTest.capture_stdout do
        cut.send(:logger).debug("instance log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest:71 - instance log message\n"
    end
  end

  context :reload do
    let(:cut) { Smith::ClassUnderTest.new }

    it "should change log level to info when logger is invoked as a class method" do
      log_output = Smith::ClassUnderTest.capture_stdout do
        Smith::ClassUnderTest.send(:logger).debug("class log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest: - class log message\n"

      Smith::ClassUnderTest.send(:log_level, :info)
      log_output = Smith::ClassUnderTest.capture_stdout do
        Smith::ClassUnderTest.send(:logger).info("class log message")
      end
      log_output.should == " INFO - Smith::ClassUnderTest: - class log message\n"
    end


    it 'should change log level to info when logger is invoked as a instance method' do
      log_output = Smith::ClassUnderTest.capture_stdout do
        cut.send(:logger).debug("instance log message")
      end
      log_output.should == "DEBUG - Smith::ClassUnderTest: - instance log message\n"

      cut.send(:log_level, :info)

      log_output = Smith::ClassUnderTest.capture_stdout do
        cut.send(:logger).info("instance log message")
      end
      log_output.should == " INFO - Smith::ClassUnderTest: - instance log message\n"
    end
  end
end
