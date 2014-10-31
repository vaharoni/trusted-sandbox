require 'spec_helper'

# This should not be run by CI as it requires server installation.

describe 'integration testing' do
  describe 'with general purpose class' do

    describe 'memory limit' do
      it 'raises error when limited' do
        response = TrustedSandbox.with_options(memory_limit: 50_000_000) do |s|
          s.run_code('x = "*" * 50_000_000')
        end
        response.stderr.should start_with('Killed')
      end

      it 'works when not limited' do
        response = TrustedSandbox.run_codewith_options(memory_limit: 50_000_000) do |s|
          s.run_code('x = "*" * 50_000_000')
        end
        response.stderr.should start_with('Killed')
      end
    end

  end
end