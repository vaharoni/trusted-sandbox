module TrustedSandbox

  require 'yaml'
  require 'docker'
  require 'trusted_sandbox/config'
  require 'trusted_sandbox/defaults'
  require 'trusted_sandbox/errors'
  require 'trusted_sandbox/general_purpose'
  require 'trusted_sandbox/request_serializer'
  require 'trusted_sandbox/response'
  require 'trusted_sandbox/runner'
  require 'trusted_sandbox/uid_pool'
  require 'trusted_sandbox/version'

  def self.test_connection
    Docker.version
    true
  end

  # Usage:
  #   TrustedSandbox.config do |c|
  #     c.pool_size = 10
  #     # ...
  #   end
  def self.config
    @config ||= Defaults.send(:new).override config_overrides_from_file
    yield @config if block_given?
    @config.finished_configuring
  end

  def self.config_overrides_from_file(env = nil)
    yaml_path = %w(trusted_sandbox.yml config/trusted_sandbox.yml).find {|x| File.exist?(x)}
    return {} unless yaml_path

    env ||= ENV['TRUSTED_SANDBOX_ENV'] || ENV['RAILS_ENV'] || 'development'
    YAML.load_file(yaml_path)[env]
  end

  def self.uid_pool
    @uid_pool ||= UidPool.new config.host_uid_pool_lock_path, config.pool_min_uid, config.pool_max_uid,
                              timeout: config.pool_timeout, retries: config.pool_retries, delay: config.pool_delay
  end

  # @param config_override [Hash] allows overriding configurations for a specific invocation
  def self.with_options(config_override={})
    yield new_runner(config_override)
  end

  # @param klass [Class] the class to be instantiated in the safe sandbox
  # @param *args [Array] arguments to send to klass#new
  def self.run(klass, *args)
    new_runner.run(klass, *args)
  end

  def self.run!(klass, *args)
    new_runner.run!(klass, *args)
  end

  def self.run_code(code, args={})
    new_runner.run(TrustedSandbox::GeneralPurpose, code, args)
  end

  def self.run_code!(code, args={})
    new_runner.run!(TrustedSandbox::GeneralPurpose, code, args)
  end

  def self.new_runner(config_override = {})
    Runner.new(config, uid_pool, config_override)
  end
end

# Run the configuration block
TrustedSandbox.config