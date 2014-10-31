require 'spec_helper'

describe TrustedSandbox::Config do
  before do
    @defaults = TrustedSandbox::Defaults.send(:new)
  end

  describe 'override mechanism' do
    before do
      @subject = @defaults.override cpu_shares: 2
    end

    it 'ensures defaults have what we expect' do
      @defaults.cpu_shares.should == 1
      @defaults.execution_timeout.should == 15
    end

    it 'works' do
      @subject.cpu_shares.should == 2
      @subject.execution_timeout.should == 15
    end
  end

  describe '#pool_max_id' do
    before do
      @subject = @defaults.override pool_min_uid: 100, pool_size: 10
    end
    it 'works' do
      @subject.pool_max_uid.should == 109
    end
  end

  describe 'docker_url=' do
    before do
      @url = 'http://localhost'
      @subject = @defaults.override docker_url: @url
    end
    it 'sets up Docker' do
      Docker.url.should == @url
    end
  end

  describe 'host_code_root_path= and host_uid_pool_lock_path=' do
    before do
      @subject = @defaults.override host_code_root_path: '~/tmp', host_uid_pool_lock_path: '~/tmp2'
    end
    it 'expands the path' do
      @subject.host_code_root_path.should == File.expand_path('~/tmp')
      @subject.host_uid_pool_lock_path.should == File.expand_path('~/tmp2')
    end
  end

  describe 'docker_cert_path and docker_options' do
    before do
      @subject = @defaults.override docker_cert_path: '~/tmp', docker_options: { ssl_verify_peer: true }
    end

    it 'works' do
      @subject.finished_configuring
      Docker.options = { private_key_path: File.expand_path('~/tmp/key.pem'),
                         certificate_path: File.expand_path('~/tmp/cert.pem'),
                         ssl_verify_peer: true }
    end
  end

  describe 'docker authentication' do
    context 'user did not request to authenticate' do
      before do
        @subject = @defaults.override
        dont_allow(Docker).authenticate!
      end
      it 'does not perform authentication' do
        @subject.finished_configuring
      end
    end
    context 'user requested to authenticate' do
      before do
        @subject = @defaults.override docker_login: {user: 'user', password: 'password', email: 'email'}
        mock(Docker).authenticate!(username: 'user', password: 'password', email: 'email').times(1)
      end

      it 'call Docker.authenticate!' do
        @subject.finished_configuring
      end

      it 'does not call Docker.authenticate! twice' do
        2.times { @subject.finished_configuring }
      end
    end
  end
end