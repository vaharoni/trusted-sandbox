require 'thor'

module TrustedSandbox
  class Cli < Thor
    desc 'test'
    def test(hi)
      puts hi
    end
  end
end