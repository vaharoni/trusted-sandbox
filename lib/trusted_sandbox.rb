require 'trusted_sandbox/version'
require 'trusted_sandbox/errors'

module TrustedSandbox

  # Usage:
  #   TrustedSandbox.config do |c|
  #     c.pool_size = 10
  #     # ...
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
end
