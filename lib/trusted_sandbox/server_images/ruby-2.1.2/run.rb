begin
  require 'active_support'
  require 'yaml'

  manifest_file_path = '/home/sandbox/src/manifest'
  input_file_path = '/home/sandbox/src/input'
  output_file_path = '/home/sandbox/src/output'

  manifest = YAML.load_file(manifest_file_path)
  manifest.each {|f| require_relative "src/#{f}"}

  data = File.binread(input_file_path)
  klass_name, args = Marshal.load(data)
  klass = ActiveSupport::Inflector.constantize klass_name

  obj = klass.new(*args)
  output = obj.run

  File.binwrite output_file_path, Marshal.dump(status: 'success', output: output)
rescue => e
  File.binwrite output_file_path, Marshal.dump(status: 'error', error: e)
end