require 'spec_helper'

# This should not be run by CI as it requires server installation.

describe 'integration testing' do

  describe 'memory limit' do
    it 'raises error when limited' do
      response = TrustedSandbox.with_options(memory_limit: 50_000_000) do |s|
        s.run_code('x = "*" * 50_000_000')
      end
      response.valid?.should == false
      response.stderr.should == ["Killed\n"]
    end

    it 'works when not limited' do
      response = TrustedSandbox.with_options(memory_limit: 100_000_000) do |s|
        s.run_code('x = "*" * 50_000_000')
      end
      response.stderr.should be_empty
      response.stdout.should be_empty
      response.valid?.should == true
    end
  end

  describe 'time limit' do
    it 'raises error' do
      response = TrustedSandbox.with_options(execution_timeout: 1) do |s|
        s.run_code('puts "hi"; while true; end')
      end
      response.valid?.should == false
      response.error.is_a?(Timeout::Error).should == true
      response.error_to_raise.is_a?(TrustedSandbox::ExecutionTimeoutError).should == true
    end
  end
end