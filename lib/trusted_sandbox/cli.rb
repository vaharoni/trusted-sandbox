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

    desc 'generate_image VERSION', 'Creates the Docker image files and places them into the `server_images` directory. Default version is 2.1.2'
    def generate_image(image_version = '2.1.2')
      local_image = "server_images/#{image_version}"
      gem_image = File.expand_path("../#{local_image}", __FILE__)

      puts "Image #{image_version} does not exist" unless Dir.exist?(gem_image)
      puts "Directory #{local_image} already exists" or return if Dir.exist?(local_image)

      puts "Copying #{image_version} into #{local_image}"
      FileUtils.mkdir_p 'server_images'
      FileUtils.cp_r gem_image, local_image
    end

    desc 'set_quotas QUOTA_KB', 'Sets the quota for all the UIDs in the pool. This requires additional installation. Refer to the README file.'
    def set_quotas(quota_kb)
      (TrustedSandbox.config.pool_min_uid..TrustedSandbox.config.pool_max_uid).each do |uid|
        `setquota -u #{uid} 0 #{quota_kb} 0 0 /`
      end
    end
  end
end