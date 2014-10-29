require 'bundler/gem_tasks'
require 'docker'
require 'trusted_sandbox'

desc 'Builds Docker image 1.9.3'
task :build_193 do
  docker_env = "DOCKER_HOST=#{ENV['DOCKER_HOST'] || TrustedSandbox.config.docker_url} DOCKER_CERT_PATH=#{ENV['DOCKER_CERT_PATH'] || TrustedSandbox.config.docker_cert_path} DOCKER_TLS_VERIFY=#{ENV['DOCKER_TLS_VERIFY'] || 1}"
  `#{docker_env} docker build -t "trusted_sandbox:1.9.3.v1" lib/trusted_sandbox/server_images/1.9.3`
end

desc 'Builds Docker image 2.1.2'
task :build_212 do
  docker_env = "DOCKER_HOST=#{ENV['DOCKER_HOST'] || TrustedSandbox.config.docker_url} DOCKER_CERT_PATH=#{ENV['DOCKER_CERT_PATH'] || TrustedSandbox.config.docker_cert_path} DOCKER_TLS_VERIFY=#{ENV['DOCKER_TLS_VERIFY'] || 1}"
  `#{docker_env} docker build -t "trusted_sandbox:2.1.2.v1" lib/trusted_sandbox/server_images/2.1.2`
end
