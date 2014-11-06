require 'trusted_sandbox'
require 'thor'

module TrustedSandbox
  class Cli < Thor
    desc 'install', 'Creates trusted_sandbox.yml in `config`, if this directory exists, or in the current directory otherwise'
    def install
      curr_dir_file = 'trusted_sandbox.yml'
      config_dir_file = 'config/trusted_sandbox.yml'

      puts "#{curr_dir_file} already exists" or return if File.exist?(curr_dir_file)
      puts "#{config_dir_file} already exists" or return if File.exist?(config_dir_file)

      target_file = Dir.exist?('config') ? config_dir_file : curr_dir_file

      puts "Creating #{target_file}"
      FileUtils.cp File.expand_path('../config/trusted_sandbox.yml', __FILE__), target_file
    end

    desc 'test', 'Checks Trusted Sandbox can connect to Docker'
    def test
      TrustedSandbox.test_connection
      puts 'Trusted Sandbox seems to be configured correctly!'
    end

    desc 'ssh UID', 'Launch a container with shell and mount the code folder. Works only if keep_code_folders is true. UID is the suffix of the code folder'
    def ssh(uid)
      raise 'keep_code_folders must be set to true' unless TrustedSandbox.config.keep_code_folders
      local_code_dir = File.join TrustedSandbox.config.host_code_root_path, uid
      `docker run -it -v #{local_code_dir}:/home/sandbox/src --entrypoint="/bin/bash" #{TrustedSandbox.config.docker_image_name} -s`
    end

    desc 'generate_image IMAGE_NAME', 'Creates the Docker image files and places them into the `trusted_sandbox_images` directory. Default name is ruby-2.1.2'
    def generate_image(image_name = 'ruby-2.1.2')
      target_dir = 'trusted_sandbox_images'
      target_image_path = "#{target_dir}/#{image_name}"
      gem_image_path = File.expand_path("../server_images/#{image_name}", __FILE__)

      puts "Image #{image_name} does not exist" or return unless Dir.exist?(gem_image_path)
      puts "Directory #{target_image_path} already exists" or return if Dir.exist?(target_image_path)

      puts "Copying #{image_name} into #{target_image_path}"
      FileUtils.mkdir_p target_dir
      FileUtils.cp_r gem_image_path, target_image_path
    end

    desc 'generate_images', 'Copies all Docker images files into `trusted_sandbox_images` directory'
    def generate_images
      target_dir = 'trusted_sandbox_images'
      source_dir = File.expand_path("../server_images", __FILE__)

      puts "Directory #{target_dir} already exists" or return if Dir.exist?(target_dir)
      puts "Copying images into #{target_dir}"

      FileUtils.cp_r source_dir, target_dir
    end

    desc 'set_quotas QUOTA_KB', 'Sets the quota for all the UIDs in the pool. This requires additional installation. Refer to the README file.'
    def set_quotas(quota_kb)
      from = TrustedSandbox.config.pool_min_uid
      to = TrustedSandbox.config.pool_max_uid
      puts "Configuring quota for UIDs [#{from}..#{to}]"
      (from..to).each do |uid|
        `sudo setquota -u #{uid} 0 #{quota_kb} 0 0 /`
      end
    end

    desc 'reset_uid_pool UID', 'Release the provided UID from the UID-pool. If the UID is omitted, all UIDs that were reserved will be released, effectively resetting the pool'
    def reset_uid_pool(uid = nil)
      if uid
        TrustedSandbox.uid_pool.release uid
      else
        TrustedSandbox.uid_pool.release_all
      end
    end

    desc 'ssh UID', 'Shows how to run a container with the current configuration settings. If UID is provided, it includes mounting instructions.'
    def ssh(uid=nil)
      uid_string = uid ? "-v #{File.join(TrustedSandbox.config.host_code_root_path, uid)}:/home/sandbox/src" : nil
      puts %{docker run -it #{uid_string} --entrypoint="/bin/bash" #{TrustedSandbox.config.docker_image_name} -s}
    end
  end
end