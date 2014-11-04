module TrustedSandbox
  class RequestSerializer

    attr_reader :host_code_dir_path, :manifest_file_name, :input_file_name

    # @param host_code_dir_path [String] path to the folder where the argument value needs to be stored
    # @param manifest_file_name [String] name of manifest file inside the host_code_dir_path
    # @param input_file_name [String] name of input file inside the host_code_dir_path
    def initialize(host_code_dir_path, manifest_file_name, input_file_name)
      @host_code_dir_path = host_code_dir_path
      @input_file_name = input_file_name
      @manifest_file_name = manifest_file_name
    end

    # @param klass [Class] class name to be serialized
    # @param args [Array] the array of argument values
    # @return [String] full path of the argument that was stored
    def serialize(klass, *args)
      self.klass = klass
      copy_code_file
      create_manifest_file

      data = Marshal.dump([klass.name, args])
      File.binwrite input_file_path, data
    end

    private

    def input_file_path
      File.join host_code_dir_path, input_file_name
    end

    def manifest_file_path
      File.join host_code_dir_path, manifest_file_name
    end

    # = Methods depending on @klass

    attr_accessor :klass

    def source_file_path
      file, _line = klass.instance_method(:initialize).source_location
      raise InvocationError.new("Cannot find location of class #{klass.name}") unless File.exist?(file.to_s)
      file
    end

    def dest_file_name
      File.basename(source_file_path)
    end

    def dest_file_path
      File.join host_code_dir_path, dest_file_name
    end

    def copy_code_file
      FileUtils.cp source_file_path, dest_file_path
    end

    def create_manifest_file
      File.open(manifest_file_path, 'w') do |f|
        # In the near future this will change to a list of files, hence we use array
        f.write [dest_file_name].to_yaml
      end
    end

  end
end