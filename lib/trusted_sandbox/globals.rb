class TrustedSandbox

  # Usage:
  #   TrustedSandbox.config do |c|
  #     c.pool_size = 10
  #     c.min_uid = 10000
  #     c.pool_timeout = 3
  #     c.pool_retries = 5
  #     c.pool_delay = 0.5
  #     c.docker_url = ENV['DOCKER_HOST']
  #     c.docker_cert_path = ENV['DOCKER_CERT_PATH']
  #     c.docker_image_repo = 'runner'
  #     c.docker_image_tag = 'latest'
  #   end
  def self.config
    @config ||= Defaults.send(:new).override
    yield @config if block_given?
    @config
  end

  def self.uid_pool
    @uid_pool ||= UidPool.new config.pool_min_uid, config.pool_max_uid,
                              timeout: config.pool_timeout, retries: config.pool_retries, delay: config.pool_delay
  end

  # @param config_override [Hash] allows overriding configurations for a specific invocation
  def self.with_options(config_override={})
    yield new(config_override)
  end

  # @param klass [Class] the class to be instantiated in the safe sandbox
  # @param *args [Array] arguments to send to klass#new
  def self.run(klass, *args)
    new.run(klass, *args)
  end

  def self.run!(klass, *args)
    new.run!(klass, *args)
  end

  attr_reader :config

  # @param config_override [Hash] allows overriding configurations for a specific invocation
  def initialize(config_override={})
    @config = self.class.config.override(config_override)
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