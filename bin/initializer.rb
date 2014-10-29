# require 'docker'
# require_relative '../lib/trusted_sandbox'
# require_relative '../app/user_function'
#
# TrustedSandbox.config do |c|
#   c.docker_url = 'https://192.168.59.103:2376'
#   c.docker_cert_path = File.expand_path('~/.boot2docker/certs/boot2docker-vm')
#   c.docker_image_repo = 'runner6'
# end
#
# input = { number: 10 }
#
# untrusted_code = <<-CODE
# input[:number] ** 2
# CODE

# Docker.url = ENV['DOCKER_HOST'] || 'https://192.168.59.103:2376'
#
# cert_path = ENV['DOCKER_CERT_PATH'] || File.expand_path('~/.boot2docker/certs/boot2docker-vm')
# Docker.options = {
#   private_key_path: "#{cert_path}/key.pem",
#   certificate_path: "#{cert_path}/cert.pem",
#   ssl_verify_peer: false
# }

# dir = File.expand_path('./server')
# Docker::Image.build_from_dir(dir)