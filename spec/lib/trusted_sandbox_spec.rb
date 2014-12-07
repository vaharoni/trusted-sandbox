require 'spec_helper'

describe TrustedSandbox do
  describe '#config_overrides_from_file' do
    context 'when file does not exist' do
      before do
        stub(File).exist? { false }
      end

      it 'returns empty hash' do
        TrustedSandbox.config_overrides_from_file.should == {}
      end
    end

    context 'when file exists' do
      before do
        stub(File).exist? { true }
      end

      context 'no environment' do
        before do
          @dev_hash = {'dev' => true}
          stub(YAML).load_file { {'development' => @dev_hash} }
        end

        it 'returns the hash from the development environment' do
          TrustedSandbox.config_overrides_from_file.should == @dev_hash
        end
      end

      context 'test environment' do
        before do
          @test_hash = {'test' => true}
          stub(YAML).load_file { {'test' => @test_hash} }
        end

        context 'from TRUSTED_SANDBOX_ENV' do
          before do
            ENV['TRUSTED_SANDBOX_ENV'] = 'test'
          end

          it 'returns the hash from the test environment' do
            TrustedSandbox.config_overrides_from_file.should == @test_hash
          end
        end

        context 'from RAILS_ENV' do
          before do
            ENV['RAILS_ENV'] = 'test'
          end

          it 'returns the hash from the test environment' do
            TrustedSandbox.config_overrides_from_file.should == @test_hash
          end
        end
      end

      context 'file does not contain environment key' do
        before do
          @dev_hash = {'dev' => true}
          stub(YAML).load_file { {'development' => @dev_hash} }
          ENV['TRUSTED_SANDBOX_ENV'] = 'test'
        end

        it 'returns an empty hash' do
          TrustedSandbox.config_overrides_from_file.should == {}
        end
      end
    end

  end

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