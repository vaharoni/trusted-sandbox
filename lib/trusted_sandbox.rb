require 'yaml'
require 'docker'
require 'trusted_sandbox/api'
require 'trusted_sandbox/config'
require 'trusted_sandbox/defaults'
require 'trusted_sandbox/errors'
require 'trusted_sandbox/request_serializer'
require 'trusted_sandbox/response'
require 'trusted_sandbox/runner'
require 'trusted_sandbox/tasks'
require 'trusted_sandbox/uid_pool'
require 'trusted_sandbox/version'

module TrustedSandbox

  # Usage:
  #   TrustedSandbox.config do |c|
  #     c.pool_size = 10
  #     # ...
  #   end
  def self.config
      @config ||= Defaults.send(:new).override config_overrides_from_file
    yield @config if block_given?
    @config
  end

  def self.config_overrides_from_file(env = nil)
    yaml_path = %w(trusted_sandbox.yml config/trusted_sandbox.yml).find {|x| File.exist?(x)}
    return {} unless yaml_path

    env ||= ENV['RAILS_ENV'] || ENV['TRUSTED_SANDBOX_ENV'] || 'development'
    YAML.load_file(yaml_path)[env]
  end

  def self.uid_pool
    @uid_pool ||= UidPool.new config.pool_min_uid, config.pool_max_uid,
                              timeout: config.pool_timeout, retries: config.pool_retries, delay: config.pool_delay
  end

  # @param config_override [Hash] allows overriding configurations for a specific invocation
  def self.with_options(config_override={})
    yield Api.new(config, uid_pool, config_override)
  end

  # @param klass [Class] the class to be instantiated in the safe sandbox
  # @param *args [Array] arguments to send to klass#new
  def self.run(klass, *args)
    Api.new(config, uid_pool).run(klass, *args)
  end

  def self.run!(klass, *args)
    Api.new(config, uid_pool).run!(klass, *args)
  end
end
