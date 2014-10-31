module TrustedSandbox

  # This is a general purpose class that can be used to run untrusted code in a container using TrustedSandbox.
  # Usage:
  #
  #   TrustedSandbox.run! TrustedSandbox::GeneralPurpose, "1 + 1"
  #   # => 2
  #
  #   TrustedSandbox.run! TrustedSandbox::GeneralPurpose, "input[:a] + input[:b]", input: {a: 1, b: 2}
  #   # => 3
  #
  class GeneralPurpose
    def initialize(code, args={})
      @code = code
      args.each do |name, value|
        singleton_klass = class << self; self; end
        singleton_klass.class_eval { attr_reader name }
        instance_variable_set "@#{name}", value
      end
    end

    def run
      eval @code
    end
  end
end