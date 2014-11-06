require 'spec_helper'

describe TrustedSandbox::HostRunner do

  before do
    @defaults = TrustedSandbox::Defaults.send(:new).override(quiet_mode: true)
    @uid_pool = Object.new
  end

  describe 'UID pool and code dir handling' do
    context 'keep_code_folders=false' do
      before do
        mock(@uid_pool).lock { 100 }
        mock(@uid_pool).release(100) {}
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, keep_code_folders: false
        stub(@subject).create_container
        stub(@subject).start_container
      end

      it 'locks and releases from UID pool' do
        @subject.run TrustedSandbox::HostRunner
      end

      it 'deletes the code folder' do
        @subject.run TrustedSandbox::HostRunner
        Dir.exists?(@subject.send(:code_dir_path)).should == false
      end
    end

    context 'keep_code_folders=true' do
      before do
        mock(@uid_pool).lock { 100 }
        dont_allow(@uid_pool).release
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, keep_code_folders: true
        stub(@subject).create_container
        stub(@subject).start_container
      end

      it 'locks but does not release from UID pool' do
        @subject.run TrustedSandbox::HostRunner
      end

      it 'does not delete the code folder' do
        @subject.run TrustedSandbox::HostRunner
        Dir.exists?(@subject.send(:code_dir_path)).should == true
      end
    end
  end

  describe 'container creation' do
    before do
      stub(@uid_pool).lock { 100 }
      stub(@uid_pool).release(100) {}

      container = Object.new
      @container = container

      create_req = {}
      stub(Docker::Container).create { |req| create_req.clear; create_req.merge!(req); container }
      @create_req = create_req

      start_req = {}
      stub(container).start { |req| start_req.clear; start_req.merge!(req) }
      @start_req = start_req

      mock(container).attach(stream: true, stdin: nil, stdout: true, stderr: true, logs: true, tty: false) { ['stdout', 'stderr'] }
    end

    context 'keep_containers=true' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, keep_containers: true
        dont_allow(@container).delete
      end

      it 'does not delete the container' do
        @subject.run TrustedSandbox::HostRunner
      end
    end

    context 'keep_containers=false' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, keep_containers: false
        mock(@container).delete(force: true) {}
      end

      it 'does not delete the container' do
        @subject.run TrustedSandbox::HostRunner
      end
    end

    context 'basic request parameters' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, cpu_shares: 5, memory_limit: 100,
                                              docker_image_name: 'image', container_code_path: '/code',
                                              network_access: false, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right requests' do
        @create_req.should == {"CpuShares"=>5, "Memory"=>100, "AttachStdin"=>false, "AttachStdout"=>true, "AttachStderr"=>true, "Tty"=>false, "OpenStdin"=>false, "StdinOnce"=>false, "Cmd"=>["100"], "Image"=>"image", "Volumes"=>{"/code"=>{}}, "NetworkDisabled"=>true}
        @start_req.should == {"Binds"=>["#{File.expand_path('tmp/code_dirs/100')}:/code"]}
      end
    end

    context 'enable_quotas=true' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, enable_quotas: true, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['Env'].should == ['USE_QUOTAS=1']
      end
    end

    context 'enable_quotas=false' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, enable_quotas: false, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['Env'].should be_nil
      end
    end

    context 'enable_swap_limit=true' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, enable_swap_limit: true, memory_swap_limit: 200, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['MemorySwap'].should == 200
      end
    end

    context 'enable_swap_limit=false' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, enable_swap_limit: false, memory_swap_limit: 200, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['MemorySwap'].should be_nil
      end
    end

    context 'network_access=true' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, network_access: true, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['NetworkDisabled'].should == false
      end
    end

    context 'network_access=false' do
      before do
        @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, network_access: false, keep_containers: true
        @subject.run TrustedSandbox::HostRunner
      end

      it 'sends the right request' do
        @create_req['NetworkDisabled'].should == true
      end
    end
  end

  # See more in integration testing
  describe 'shortcut used' do
    before do
      dont_allow(TrustedSandbox::RequestSerializer).new
      dont_allow(@uid_pool).lock
      dont_allow(Docker::Container).create
      @subject = TrustedSandbox::HostRunner.new @defaults, @uid_pool, shortcut: true
    end

    it 'works' do
      @subject.run_code!('true').should == true
    end
  end
end
