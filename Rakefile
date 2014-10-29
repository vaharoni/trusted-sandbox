require 'bundler/gem_tasks'
require 'docker'
require 'trusted_sandbox'

desc 'Builds Docker image 1.9.3'
task :build_193 do
  TrustedSandbox.config
  image = Docker::Image.build_from_dir('lib/trusted_sandbox/server_images/1.9.3')
  image.tag repo: 'trusted_sandbox', tag: '1.9.3.v1'
end

desc 'Builds Docker image 2.1.2'
task :build_212 do
  TrustedSandbox.config
  image = Docker::Image.build_from_dir('lib/trusted_sandbox/server_images/2.1.2')
  image.tag repo: 'trusted_sandbox', tag: '2.1.2.v1'
end
