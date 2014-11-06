module TrustedSandbox
  class Defaults < Config

    def initialize
      self.docker_options = {}
      self.docker_image_name = 'vaharoni/trusted_sandbox:ruby-2.1.2.v2'
      self.memory_limit = 50 * 1024 * 1024
      self.memory_swap_limit = 50 * 1024 * 1024
      self.cpu_shares = 1
      self.execution_timeout = 15
      self.network_access = false
      self.enable_swap_limit = false
      self.enable_quotas = false
      self.host_code_root_path = 'tmp/code_dirs'
      self.host_uid_pool_lock_path = 'tmp/uid_pool_lock'

      self.docker_url = ENV['DOCKER_HOST'] if ENV['DOCKER_HOST']
      self.docker_cert_path = ENV['DOCKER_CERT_PATH'] if ENV['DOCKER_CERT_PATH']

      # Note, changing these may require changing Dockerfile and run.rb and rebuilding the docker image
      self.container_code_path = '/home/sandbox/src'
      self.container_manifest_filename = 'manifest'
      self.container_input_filename = 'input'
      self.container_output_filename = 'output'

      # Note, changing these requires running `rake trusted_sandbox:set_quotas`
      self.pool_min_uid = 20000
      self.pool_size = 5000

      self.keep_code_folders = false
      self.keep_containers = false

      self.quiet_mode = false
      self.shortcut = false
    end

  end
end