require 'spec_helper'

# This should not be run by CI as it requires server installation.

describe 'integration testing' do

  describe 'sanity test' do
    it 'works for inline' do
      TrustedSandbox.run_code!('input[:x] ** 2', input: {x: 10}).should == 100

      response = TrustedSandbox.run_code('puts "hi"; input[:x] ** 2', input: {x: 10})
      response.valid?.should == true
      response.output.should == 100
      response.stdout.should == ["hi\n"]
    end

    it 'works for a class' do
      TrustedSandbox.run!(TrustedSandbox::GeneralPurpose, 'input[:x] ** 2', input: {x: 10}).should == 100

      response = TrustedSandbox.run(TrustedSandbox::GeneralPurpose, 'puts "hi"; input[:x] ** 2', input: {x: 10})
      response.valid?.should == true
      response.output.should == 100
      response.stdout.should == ["hi\n"]
    end

    it 'works when there is an error' do
      expect {TrustedSandbox.run_code!('asfsadf')}.to raise_error(TrustedSandbox::UserCodeError)

      response = TrustedSandbox.run_code('asfsadf')
      response.valid?.should == false
      response.output.should == nil
      response.status.should == 'error'
      response.error.is_a?(NameError).should == true
      response.error_to_raise.is_a?(TrustedSandbox::UserCodeError).should == true
    end
  end

  describe 'memory limit' do
    it 'raises error when limited' do
      response = TrustedSandbox.with_options(memory_limit: 50_000_000) do |s|
        s.run_code('x = "*" * 50_000_000; nil')
      end
      response.valid?.should == false
      response.stderr.should == ["Killed\n"]
    end

    it 'works when not limited' do
      response = TrustedSandbox.with_options(memory_limit: 100_000_000) do |s|
        s.run_code('x = "*" * 50_000_000; nil')
      end
      response.stderr.should be_empty
      response.stdout.should be_empty
      response.valid?.should == true
    end
  end

  describe 'network limit' do
    it 'raises error when limited' do
      response = TrustedSandbox.with_options(network_access: false) do |s|
        s.run_code('`ping www.google.com -c 1; echo $?`.split("\n").last')
      end
      response.stderr.should == ["ping: unknown host www.google.com\n"]
      response.output.to_i.should_not == 0
    end

    it 'works when not limited' do
      response = TrustedSandbox.with_options(network_access: true) do |s|
        s.run_code('`ping www.google.com -c 1; echo $?`.split("\n").last')
      end
      response.stderr.should be_empty
      response.output.to_i.should == 0
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