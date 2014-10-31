require 'spec_helper'

# Note! Will only work on linux machine that is configured appropriately with user quotas of 10 MB.
# This should not be run by CI.

# Usage from a configured server:
# rspec spec/integration/quota_spec.rb

describe 'quota limit integration testing' do
  it 'works when quotas are unlimited' do
    response = TrustedSandbox.with_options(enable_quotas: false) do |s|
      s.run_code "File.open('test','w') {|f| f.write '*' * 15_000_000}"
    end
    response.valid?.should == true
  end

  # rspec spec/integration/quota_spec.rb --example "quota limit integration testing does not work when quotas are limited"
  it 'does not work when quotas are limited' do
    response = TrustedSandbox.with_options(enable_quotas: true) do |s|
      s.run_code "File.open('test','w') {|f| f.write '*' * 15_000_000}"
    end
    response.valid?.should == false
    response.stderr.any? {|row| row =~ /disk quota exceeded/i}.should == true
  end
end