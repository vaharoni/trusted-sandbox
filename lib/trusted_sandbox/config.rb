module TrustedSandbox

  # Allows chaining so that specific invocations can override configurations.
  # Usage:
  #   general_config = Defaults.new.override(pool_size: 10, memory_limit: 100)
  #   specific_invocation = general_config.override(memory_limit: 200)
  #
  class Config
    attr_reader :other_config

    def self.attr_reader_with_fallback(*names)
      names.each do |name|
        define_method name do
          value = instance_variable_get("@#{name}")
          return value unless value.nil?
          return other_config.send(name) if other_config.respond_to?(name)
          nil
        end
      end
    end

    def self.attr_accessor_with_fallback(*names)
      names.each do |name|
        attr_reader_with_fallback(name)
        attr_writer(name)
      end
    end

    attr_accessor_with_fallback :pool_size, :pool_min_uid, :pool_timeout, :pool_retries, :pool_delay, :docker_options,
                                :memory_limit, :memory_swap_limit, :cpu_shares, :docker_image_name,
                                :execution_timeout, :network_access, :enable_swap_limit, :enable_quotas,
                                :container_code_path, :container_input_filename, :container_output_filename,
                                :keep_code_folders, :keep_containers

    attr_reader_with_fallback :host_code_root_path, :host_uid_pool_lock_path

    attr_reader :docker_url, :docker_cert_path, :docker_auth_email, :docker_auth_user, :docker_auth_password,
                :docker_auth_needed

    def override(params={})
      Config.send :new, self, params
    end

    def pool_max_uid
      pool_min_uid + pool_size - 1
    end

    def docker_url=(value)
      @docker_url = value
      Docker.url = value
    end

    def docker_cert_path=(value)
      @docker_cert_path = File.expand_path(value)
      @docker_options_for_cert = {
          private_key_path: "#{@docker_cert_path}/key.pem",
          certificate_path: "#{@docker_cert_path}/cert.pem",
          ssl_verify_peer: false
      }
    end

    def host_code_root_path=(path)
      @host_code_root_path = File.expand_path(path)
    end

    def host_uid_pool_lock_path=(path)
      @host_uid_pool_lock_path = File.expand_path(path)
    end

    # All keys are mandatory
    # @option :user [String]
    # @option :password [String]
    # @option :email [String]
    def docker_login=(options={})
      @docker_auth_needed = true
      @docker_auth_user = options[:user] || options['user']
      @docker_auth_password = options[:password] || options['password']
      @docker_auth_email = options[:email] || options['email']
    end

    # Called to do any necessary setup to allow staged configuration
    # @return [Config] self for chaining
    def finished_configuring
      Docker.options = @docker_options_for_cert.merge(docker_options)

      return self unless @docker_auth_needed
      Docker.authenticate! username: @docker_auth_user, password: @docker_auth_password, email: @docker_auth_email
      @docker_auth_needed = false
      self
    end

    private_class_method :new

    # @params other_config [Config] config object that will be deferred to if the current config object does not
    #   contain a value for the requested configuration options
    # @params params [Hash] hash containing configuration options
    def initialize(other_config, params={})
      @docker_options_for_cert = {}
      @other_config = other_config
      params.each do |key, value|
        send "#{key}=", value
      end
    end

  end
end