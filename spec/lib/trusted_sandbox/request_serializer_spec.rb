require 'spec_helper'

describe TrustedSandbox::RequestSerializer do
  before do
    @tmp_path = 'tmp/test/request_serializer'

    @manifest_file_name = 'manifest'
    @manifest_file_path = File.expand_path File.join(@tmp_path, @manifest_file_name)

    @args_file_name = 'args'
    @args_file_path = File.expand_path File.join(@tmp_path, @args_file_name)
    FileUtils.rm_rf @tmp_path
    FileUtils.mkdir_p @tmp_path
  end

  describe '#initialize' do
    before do
      @subject = TrustedSandbox::RequestSerializer.new(@tmp_path, @manifest_file_name, @args_file_name)
    end

    it 'initializes attributes correctly' do
      @subject.host_code_dir_path.should == @tmp_path
      @subject.input_file_name.should == @args_file_name
    end

  end

  describe '#serialize' do
    before do
      @subject = TrustedSandbox::RequestSerializer.new(@tmp_path, @manifest_file_name, @args_file_name)
      @arg1 = { test: 'working' }
      @arg2 = { another_test: 'working too' }
      @subject.serialize TrustedSandbox::RequestSerializer, @arg1, @arg2

      @source_class_file = File.expand_path('lib/trusted_sandbox/request_serializer.rb')
      @target_class_file = File.expand_path File.join(@tmp_path, 'request_serializer.rb')
    end

    it 'copies the class file' do
      File.exists?(@target_class_file).should == true
      File.read(@target_class_file).should == File.read(@source_class_file)
    end

    it 'creates a manifest file' do
      File.exists?(@manifest_file_path).should == true
      YAML.load_file(@manifest_file_path).should == ['request_serializer.rb']
    end

    it 'serializes arguments' do
      File.exists?(@args_file_path).should == true
      data = File.binread(@args_file_path)
      Marshal.load(data).should == ['TrustedSandbox::RequestSerializer', [@arg1, @arg2]]
    end
  end

end