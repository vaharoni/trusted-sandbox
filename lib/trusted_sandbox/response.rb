module TrustedSandbox
  class Response

    attr_reader :host_code_dir_path, :output_file_name, :stdout, :stderr,
                :raw_response, :status, :error, :error_to_raise, :output

    # @param stdout [String, Array] response of stdout from the container
    # @param stderr [String, Array] response of stderr from the container
    # @param host_code_dir_path [String] path to the folder where the argument value needs to be stored
    # @param output_file_name [String] name of output file inside the host_code_dir_path
    def initialize(stdout = nil, stderr = nil, host_code_dir_path = nil, output_file_name = nil)
      @stdout = [stdout].flatten.compact
      @stderr = [stderr].flatten.compact
      @host_code_dir_path = host_code_dir_path
      @output_file_name = output_file_name
    end

    # = Alternative initializers

    # @param error [StandardError] error object that was raised during execution of the code
    # @param error_to_raise [Class] an error class in the TrustedSandbox module.
    # @param stdout [String]
    # @param stderr [String]
    # @return [Response] object initialized with error details
    def self.error(error, error_to_raise, stdout = nil, stderr = nil)
      obj = new(stdout, stderr)
      obj.instance_eval do
        @status = 'error'
        @error = error
        @error_to_raise = error_to_raise.new(error)
      end
      obj
    end

    # This is used when user decides not to go through docker
    # @param output [Object] the result of the code execution
    # @param stdout [String]
    # @param stderr [String]
    # @return [Response] object initialized with output
    def self.shortcut(output, stdout = nil, stderr = nil)
      obj = new(stdout, stderr)
      obj.instance_eval do
        @status = 'success'
        @output = output
      end
      obj
    end

    # @return [Boolean]
    def valid?
      status == 'success'
    end

    # @return [Object] the output returned by the container. Raises errors if encountered.
    # @raise [ContainerError, UserCodeError, InternalError] if errors were raised by the container, they are bubbled
    #   as UserCodeError
    def output!
      propagate_errors!
      output
    end

    # Parses the output file and stores the values in the appropriate ivars
    # @return [nil]
    def parse!
      unless File.exists? output_file_path
        @status = 'error'
        @error = ContainerError.new('User code did not finish properly')
        @error_to_raise = @error
        return
      end

      begin
        data = File.binread output_file_path
        @raw_response = Marshal.load(data)
      rescue => e
        @status = 'error'
        @error = e
        @error_to_raise = ContainerError.new(e)
        return
      end

      unless ['success', 'error'].include? @raw_response[:status]
        @status = 'error'
        @error = InternalError.new('Output file has invalid format')
        @error_to_raise = @error
        return
      end

      @status = @raw_response[:status]
      @output = @raw_response[:output]
      @error = @raw_response[:error]
      @error_to_raise = UserCodeError.new(@error) if @error
      nil
    end

    private

    def output_file_path
      File.join(host_code_dir_path, output_file_name)
    end

    def propagate_errors!
      return if valid?
      raise InternalError.new 'Response object is invalid but no errors were recorded.' unless error
      raise error_to_raise
    end

  end
end