begin
  require 'active_support'

  input_file_path = '/home/sandbox/src/input'
  output_file_path = '/home/sandbox/src/output'

  data = File.binread(input_file_path)
  klass_name, file_name, args = Marshal.load(data)
  require File.join('/home/sandbox/src', file_name)
  klass = ActiveSupport::Inflector.constantize klass_name

  obj = klass.new(*args)
  output = obj.run

  File.binwrite output_file_path, Marshal.dump(status: 'success', output: output)
rescue => e
  File.binwrite output_file_path, Marshal.dump(status: 'error', error: e)
end