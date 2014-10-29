module TrustedSandbox

  class Api
    attr_reader :config

    # @param config_override [Hash] allows overriding configurations for a specific invocation
    def initialize(config_override={})
      @config = TrustedSandbox.config.override(config_override)
    end

    def run(klass, *args)
      runner = Runner.new(config, self.class.uid_pool)
      runner.run(klass, *args)
    end

    def run!(klass, *args)
      runner = Runner.new(config, self.class.uid_pool)
      runner.run!(klass, *args)
    end
  end
end