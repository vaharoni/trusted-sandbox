module TrustedSandbox
  class HostRunner

    attr_reader :uid_pool, :config

    # @param config [Config]
    # @param uid_pool [UidPool]
    # @param config_override [Hash] allows overriding configurations for a specific invocation
    def initialize(config, uid_pool, config_override={})
      @config = config.override(config_override)
      @uid_pool = uid_pool
    end

    # @param klass [Class] the class object that should be run
    # @param *args [Array] arguments to send to klass#initialize
    # @return [Response]
    def run(klass, *args)
      if config.shortcut
        shortcut(klass, *args)
      else
        run_in_container(klass, *args)
      end
    end

    # @param klass [Class] the class object that should be run
    # @param *args [Array] arguments to send to klass#initialize
    # @return [Object] return value from the #eval method
    # @raise [InternalError, UserCodeError, ContainerError]
    def run!(klass, *args)
      run(klass, *args).output!
    end

    # @param code [String] code to be evaluated
    # @param args [Hash] hash to send to GeneralPurpose
    # @return [Response]
    def run_code(code, args={})
      run(GeneralPurpose, code, args)
    end

    # @param code [String] code to be evaluated
    # @param args [Hash] hash to send to GeneralPurpose
    # @return [Object] return value from the #eval method
    # @raise [InternalError, UserCodeError, ContainerError]
    def run_code!(code, args={})
      run!(GeneralPurpose, code, args)
    end

    private

    def run_in_container(klass, *args)
      create_code_dir
      serialize_request(klass, *args)
      create_container
      start_container
    ensure
      release_uid
      remove_code_dir
      remove_container
    end

    def obtain_uid
      @uid ||= uid_pool.lock
    end

    def release_uid
      uid_pool.release(@uid) if @uid and !config.keep_code_folders
    end

    def code_dir_path
      @code_dir_path ||= File.join config.host_code_root_path, obtain_uid.to_s
    end

    def remove_code_dir
      FileUtils.rm_rf code_dir_path unless config.keep_code_folders
    end

    def create_code_dir
      if config.keep_code_folders and !config.quiet_mode
        puts "Creating #{code_dir_path}"
        puts nil
        puts 'To launch and ssh into a new docker container with this directory mounted, run:'
        puts '-' * 80
        puts %{docker run -it -v #{code_dir_path}:/home/sandbox/src --entrypoint="/bin/bash" #{config.docker_image_name} -s}
        puts nil
      end

      FileUtils.mkdir_p code_dir_path
    end

    def serialize_request(klass, *args)
      serializer = RequestSerializer.new(code_dir_path, config.container_manifest_filename, config.container_input_filename)
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
      response = TrustedSandbox::Response.new stdout, stderr, code_dir_path, config.container_output_filename
      response.parse!
      response
    rescue Timeout::Error => e
      logs = @container.logs(stdout: true, stderr: true)
      TrustedSandbox::Response.error(e, TrustedSandbox::ExecutionTimeoutError, logs)
    end

    # @return [TrustedSandbox::Response]
    def shortcut(klass, *args)
      output, stdout, stderr = Timeout.timeout(config.execution_timeout) do
        begin
          $stdout = StringIO.new
          $stderr = StringIO.new
          [klass.new(*args).run, $stdout.string, $stderr.string]
        ensure
          $stdout = STDOUT
          $stderr = STDERR
        end
      end
      TrustedSandbox::Response.shortcut output, stdout, stderr
    rescue Timeout::Error => e
      TrustedSandbox::Response.error(e, TrustedSandbox::ExecutionTimeoutError, stdout, stderr)
    rescue => e
      TrustedSandbox::Response.error(e, TrustedSandbox::UserCodeError, stdout, stderr)
    end

    def remove_container
      return unless @container and !config.keep_containers
      @container.delete force: true
    end

    def create_container_request
      basic_request = {
          # 'Hostname' => '',
          # 'Domainname' => '',
          # 'User' => '',
          'CpuShares' => config.cpu_shares,
          'Memory' => config.memory_limit,
          # 'Cpuset' => '0,1',
          'AttachStdin' => false,
          'AttachStdout' => true,
          'AttachStderr' => true,
          # 'PortSpecs' => null,
          'Tty' => false,
          'OpenStdin' => false,
          'StdinOnce' => false,
          'Cmd' => [@uid.to_s],
          'Image' => config.docker_image_name,
          'Volumes' => {
              config.container_code_path => {}
          },
          # 'WorkingDir' => '',
          'NetworkDisabled' => !config.network_access,
          # 'ExposedPorts' => {
          #     '22/tcp' => {}
          # }
      }
      basic_request.merge!('MemorySwap' => config.memory_swap_limit) if config.enable_swap_limit
      basic_request.merge!('Env' => ['USE_QUOTAS=1']) if config.enable_quotas
      basic_request
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