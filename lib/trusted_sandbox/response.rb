class TrustedSandbox
  class Response

    attr_reader :host_code_dir_path, :output_file_name, :stdout, :stderr,
                :raw_response, :status, :error, :error_to_raise, :output

    # @param host_code_dir_path [String] path to the folder where the argument value needs to be stored
    # @param output_file_name [String] name of output file inside the host_code_dir_path
    def initialize(host_code_dir_path, output_file_name, stdout, stderr)
      @host_code_dir_path = host_code_dir_path
      @output_file_name = output_file_name
      @stdout = stdout
      @stderr = stderr
      parse_output_file
    end

    def valid?
      status == 'success'
    end

    def output!
      propagate_errors!
      output
    end

    private

    def output_file_path
      File.join(host_code_dir_path, output_file_name)
    end

    def parse_output_file
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
        @error = ContainerError.new('Output file has invalid format')
        @error_to_raise = @error
        return
      end

      @status = @raw_response[:status]
      @output = @raw_response[:output]
      @error = @raw_response[:error]
      @error_to_raise = UserCodeError.new(@error) if @error
    end

    def propagate_errors!
      return if valid?
      raise InternalError.new 'Response object is invalid but no errors were recorded.' unless error
      raise error_to_raise
    end

  end
end