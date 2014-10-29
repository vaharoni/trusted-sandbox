require 'trusted_sandbox'
require 'tmp/user_function'

TrustedSandbox.config do |c|
  c.docker_url = 'https://192.168.59.103:2376'
  c.docker_cert_path = File.expand_path('~/.boot2docker/certs/boot2docker-vm')
  c.docker_image_repo = 'runner6'
end

input = { number: 10 }

untrusted_code = <<-CODE
input[:number] ** 2
CODE

TrustedSandbox.run! UserFunction, untrusted_code, input

