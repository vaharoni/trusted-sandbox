module TrustedSandbox

  # This is a general purpose class that can be used to run untrusted code in a container using TrustedSandbox.
  # Usage:
  #
  #   TrustedSandbox.run! TrustedSandbox::GeneralPurpose, "1 + 1"
  #   # => 2
  #
  class GeneralPurpose
    def initialize(code)
      @code = code
    end

    def run
      eval @code
    end
  end
end