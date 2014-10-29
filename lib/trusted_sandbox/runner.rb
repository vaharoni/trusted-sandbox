module TrustedSandbox
  class Runner

    attr_reader :uid_pool, :config

    # @param config [Config]
    # @param uid_pool [UidPool]
    def initialize(config, uid_pool)
      @config = config
      @uid_pool = uid_pool
    end

    # @param klass [Class] the class object that should be run
    # @param *args [Array] arguments to send to klass#initialize
    # @return [Response]
    def run(klass, *args)
      create_code_dir
      serialize_request(klass, *args)
      create_container
      start_container
    ensure
      release_uid
      remove_code_dir unless config.keep_code_folders
      remove_container
    end

    # @param klass [Class] the class object that should be run
    # @param *args [Array] arguments to send to klass#initialize
    # @return [Response]
    # @raise [InternalError, UserCodeError, ContainerError]
    def run!(klass, *args)
      run(klass, *args).output!
    end

    private

    def obtain_uid
      @uid ||= uid_pool.lock
    end

    def release_uid
      uid_pool.release(@uid) if @uid
    end

    def code_dir_path
      @code_dir_path ||= File.join config.host_code_root_path, obtain_uid.to_s
    end

    def remove_code_dir
      FileUtils.rm_rf code_dir_path
    end

    def create_code_dir
      FileUtils.mkdir_p code_dir_path
    end

    def serialize_request(klass, *args)
      serializer = RequestSerializer.new(code_dir_path, config.container_input_filename)
      serializer.serialize(klass, *args)
    end

    def create_container
      @container = Docker::Container.create create_container_request
    end

    def start_container
      @container.start start_container_request
      stdout, stderr = nil, nil
      Timeout.timeout(config.execution_timeout) do
        stdout, stderr = @container.attach(stream: true, stdin: nil, stdout: true, stderr: true, logs: true, tty: false)
      end
      TrustedSandbox::Response.new code_dir_path, config.container_output_filename, stdout, stderr
    rescue Timeout::Error => e
      raise TrustedSandbox::ExecutionTimeoutError.new(e)
    end

    def remove_container
      return unless @container
      @container.delete force: true
    end

    def create_container_request
      {
          # 'Hostname' => '',
          # 'Domainname' => '',
          # 'User' => '',
          'Memory' => config.memory_limit,
          'MemorySwap' => config.memory_swap_limit,
          'CpuShares' => config.cpu_shares,
          # 'Cpuset' => '0,1',
          'AttachStdin' => false,
          'AttachStdout' => true,
          'AttachStderr' => true,
          # 'PortSpecs' => null,
          'Tty' => false,
          'OpenStdin' => false,
          'StdinOnce' => false,
          # 'Env' => null,
          'Cmd' => [@uid.to_s],
          'Image' => config.docker_image_name,
          'Volumes' => {
              config.container_code_path => {}
          },
          # 'WorkingDir' => '',
          'NetworkDisabled' => config.network_access,
          # 'ExposedPorts' => {
          #     '22/tcp' => {}
          # }
      }
    end

    def start_container_request
      {
          'Binds' => ["#{code_dir_path}:#{config.container_code_path}"],
          # 'Links' => ['redis3:redis'],
          # 'LxcConf' => {'lxc.utsname' => 'docker'},
          # 'PortBindings' => {'22/tcp' => [{'HostPort' => '11022'}]},
          # 'PublishAllPorts' => false,
          # 'Privileged' => false,
          # 'Dns' => ['8.8.8.8'],
          # 'VolumesFrom' => ['parent', 'other:ro'],
          # 'CapAdd' => ['NET_ADMIN'],
          # 'CapDrop' => ['MKNOD']
      }
    end
  end
end