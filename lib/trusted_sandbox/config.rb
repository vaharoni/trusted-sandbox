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
                                :docker_image_user, :docker_image_repo, :docker_image_tag,
                                :memory_limit, :memory_swap_limit, :cpu_shares,
                                :execution_timeout, :network_access, :enable_swap_limit, :enable_quotas,
                                :host_code_root_path, :container_code_path, :container_input_filename, :container_output_filename,
                                :keep_code_folders, :host_uid_pool_lock_path

    attr_reader :docker_url, :docker_cert_path

    def override(params={})
      Config.send :new, self, params
    end

    def docker_image_name
      "#{docker_image_user}/#{docker_image_repo}:#{docker_image_tag}"
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
      Docker.options = {
        private_key_path: "#{@docker_cert_path}/key.pem",
        certificate_path: "#{@docker_cert_path}/cert.pem",
        ssl_verify_peer: false
      }.merge(docker_options)
    end

    # All keys are mandatory
    # @option :user [String]
    # @option :password [String]
    # @option :email [String]
    def docker_login(options={})
      user = options[:user] || options['user']
      password = options[:password] || options['password']
      email = options[:email] || options['email']
      Docker.authenticate! username: user, password: password, email: email
    end

    private_class_method :new

    # @params other_config [Config] config object that will be deferred to if the current config object does not
    #   contain a value for the requested configuration options
    # @params params [Hash] hash containing configuration options
    def initialize(other_config, params={})
      @other_config = other_config
      params.each do |key, value|
        send "#{key}=", value
      end
    end

  end
end