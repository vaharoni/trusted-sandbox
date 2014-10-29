module TrustedSandbox

  class Api
    attr_reader :config, :uid_pool

    # @param config [Config]
    # @param uid_pool [UidPool]
    # @param config_override [Hash] allows overriding configurations for a specific invocation
    def initialize(config, uid_pool, config_override={})
      @config = config.override(config_override)
      @uid_pool = uid_pool
    end

    def run(klass, *args)
      runner = Runner.new(config, uid_pool)
      runner.run(klass, *args)
    end

    def run!(klass, *args)
      runner = Runner.new(config, uid_pool)
      runner.run!(klass, *args)
    end
  end
end