# encoding: utf-8

module Smith
  class AgencyCommand

    include Logger

    # Load and run the command specified. This method takes:
    # +target+ which is either a list of agents or the agency
    # +vars+ variables to be passed in to the command. This
    # takes the form of a hash and accessor methods are generated
    # named after the key of the hash.
    # +opts+ options for the AgencyCommand class. At the moment
    # only :auto_load is supported.
    #
    def self.run(command, target, vars, opts={})
      load_command(command) unless opts[:auto_load] == false
      Smith::AgencyCommands.const_get(Extlib::Inflection.camelize(command)).new(target).tap do |clazz|
        clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
          instance_variable_set(:"@target", target)
          def target; @target; end
        EOM

        vars.each do |k,v|
          clazz.instance_eval <<-EOM, __FILE__, __LINE__ + 1
            instance_variable_set(:"@#{k}", v)
            def #{k}; @#{k}; end
          EOM
        end

        clazz.execute(target)
      end
    end

    protected

    # The options are always in this form:
    #
    # command option [agent|agency]
    def verify_options(opts)
    end

    private

    # Load the command from the lib/smith/agency_commands directory.
    def self.load_command(cmd)
      require Smith.root_path.join('lib').join("smith").join('agency_commands').join(cmd.to_s)
    end
  end
end
