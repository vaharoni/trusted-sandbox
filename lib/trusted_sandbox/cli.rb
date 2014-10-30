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
      TrustedSandbox.test
      puts 'Trusted Sandbox seems to be configured correctly!'
    end

    desc 'generate_image VERSION', 'Creates the Docker image files and places them into the `trusted_sandbox_images` directory. Default version is 2.1.2'
    def generate_image(image_version = '2.1.2')
      target_dir = 'trusted_sandbox_images'
      target_image_path = "#{target_dir}/#{image_version}"
      gem_image_path = File.expand_path("../server_images/#{image_version}", __FILE__)

      puts "Image #{image_version} does not exist" unless Dir.exist?(gem_image_path)
      puts "Directory #{target_image_path} already exists" or return if Dir.exist?(target_image_path)

      puts "Copying #{image_version} into #{target_image_path}"
      FileUtils.mkdir_p target_dir
      FileUtils.cp_r gem_image_path, target_image_path
    end

    desc 'set_quotas QUOTA_KB', 'Sets the quota for all the UIDs in the pool. This requires additional installation. Refer to the README file.'
    def set_quotas(quota_kb)
      from = TrustedSandbox.config.pool_min_uid
      to = TrustedSandbox.config.pool_max_uid
      puts "Configuring quota for UIDs [#{from}..#{to}]"
      (from..to).each do |uid|
        `setquota -u #{uid} 0 #{quota_kb} 0 0 /`
      end
    end
  end
end