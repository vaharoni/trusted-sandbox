# require 'docker'
# require_relative '../lib/trusted_sandbox'
# require_relative '../app/user_function'
#

require 'trusted_sandbox'
TrustedSandbox.config do |c|
  c.docker_url = 'https://192.168.59.103:2376'
  c.docker_cert_path = File.expand_path('~/.boot2docker/certs/boot2docker-vm')
  c.docker_image_repo = 'runner6'
end

module App
  class UserFunction

    attr_reader :input

    def initialize(user_code, input)
      @user_code = user_code

      # This will be accessible by the user code
      @input = input
    end

    def run
      eval @user_code
    end

  end
end

input = { number: 10 }

untrusted_code = <<-CODE
input[:number] ** 2
CODE

TrustedSandbox.run! App::UserFunction, untrusted_code, input

