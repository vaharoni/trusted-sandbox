require 'spec_helper'

describe TrustedSandbox do
  describe '#with_options' do
    before do
      @default_network_access = TrustedSandbox.config.network_access
    end

    it 'overrides configuration' do
      TrustedSandbox.with_options(network_access: !@default_network_access) do |runner|
        runner.config.network_access.should == !@default_network_access
      end
    end
  end
end