module TrustedSandbox
  class InvocationError < StandardError ; end
  class PoolTimeoutError < StandardError; end
  class ContainerError < StandardError; end
  class UserCodeError < StandardError; end
  class InternalError < StandardError; end
  class ExecutionTimeoutError < StandardError; end
end