require 'spec_helper'

describe TrustedSandbox::Response do
  before do
    @tmp_path = 'tmp/test/response'
    @file_name = 'hello'
    @file_path = File.expand_path File.join(@tmp_path, @file_name)
    FileUtils.rm_rf @tmp_path
    FileUtils.mkdir_p @tmp_path
  end

  context 'no error' do
    before do
      File.binwrite @file_path, Marshal.dump(status: 'success', output: 'hi')
      @subject = TrustedSandbox::Response.new('stdout', 'stderr', @tmp_path, @file_name)
    end

    it 'instantiates correctly' do
      @subject.host_code_dir_path.should == @tmp_path
      @subject.output_file_name.should == @file_name
      @subject.stdout.should == 'stdout'
      @subject.stderr.should == 'stderr'
    end

    it 'parses the file correctly' do
      @subject.raw_response.should == {status: 'success', output: 'hi'}
      @subject.status.should == 'success'
      @subject.output.should == 'hi'
      @subject.error.should be_nil
      @subject.error_to_raise.should be_nil
      @subject.valid?.should == true
    end
  end

  context 'user error' do
    before do
      @err = 1 / 0 rescue $!
      File.binwrite @file_path, Marshal.dump(status: 'error', error: @err)
      @subject = TrustedSandbox::Response.new(nil, nil, @tmp_path, @file_name)
    end

    it 'initializes with an error' do
      @subject.raw_response.should == {status: 'error', error: @err}
      @subject.status.should == 'error'
      @subject.output.should == nil
      @subject.error.should == @err
      @subject.error_to_raise.is_a?(TrustedSandbox::UserCodeError).should == true
      expect {@subject.output!}.to raise_error(TrustedSandbox::UserCodeError)
      @subject.valid?.should == false
    end
  end

  context 'unexpected file format' do
    before do
      @err = 1 / 0 rescue $!
      File.binwrite @file_path, Marshal.dump(status: 'unexpected', output: 'hi', error: @err)
      @subject = TrustedSandbox::Response.new(@tmp_path, @file_name, nil, nil)
    end

    it 'initializes with an error' do
      @subject.raw_response.should == {status: 'unexpected', output: 'hi', error: @err}
      @subject.status.should == 'error'
      @subject.output.should == nil
      @subject.error.is_a?(TrustedSandbox::ContainerError).should == true
      @subject.error_to_raise.is_a?(TrustedSandbox::ContainerError).should == true
      expect {@subject.output!}.to raise_error(TrustedSandbox::ContainerError)
      @subject.valid?.should == false
    end
  end

  context 'file is missing' do
    before do
      @subject = TrustedSandbox::Response.new(@tmp_path, @file_name, nil, nil)
    end

    it 'initializes with an error' do
      @subject.raw_response.should == nil
      @subject.status.should == 'error'
      @subject.output.should == nil
      @subject.error.is_a?(Errno::ENOENT).should == true
      @subject.error_to_raise.is_a?(TrustedSandbox::ContainerError).should == true
      expect {@subject.output!}.to raise_error(TrustedSandbox::ContainerError)
      @subject.valid?.should == false
    end
  end
end