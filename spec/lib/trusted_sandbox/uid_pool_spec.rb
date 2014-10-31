require 'spec_helper'

describe TrustedSandbox::UidPool do
  before do
    @tmp_dir = 'tmp/uid_pool/test'
    FileUtils.rm_rf @tmp_dir
    FileUtils.mkdir_p @tmp_dir
    @class = TrustedSandbox::UidPool
  end

  describe '#initialize' do
    context 'with defaults' do
      before do
        @subject = @class.new(@tmp_dir, 1, 3)
      end

      it 'sets up defaults correctly' do
        @subject.timeout.should == 3
        @subject.retries.should == 5
        @subject.delay.should == 0.5
      end

    end

    context 'with other values' do
      before do
        @subject = @class.new(@tmp_dir, 1, 3, 'timeout' => 5, retries: 10, 'delay' => 1)
      end

      it 'sets up values correctly' do
        @subject.timeout.should == 5
        @subject.retries.should == 10
        @subject.delay.should == 1
      end
    end

  end

  describe 'usage' do
    before do
      @subject = @class.new(@tmp_dir, 1, 3, retries: 1, timeout: 0.1, delay: 0.1)
      @subject.release_all
    end

    describe '#lock' do
      context 'There are still available IDs' do
        it 'gives the UIDs' do
          [@subject.lock, @subject.lock, @subject.lock].should == [1, 2, 3]
        end
      end

      context 'There are no available IDs' do
        before do
          3.times { @subject.lock }
        end

        it 'raises an error' do
          expect {@subject.lock}.to raise_error(TrustedSandbox::PoolTimeoutError)
        end
      end
    end

    describe '#available, #used, #release' do
      before do
        @subject.release_all
        @uid = @subject.lock
      end
      it 'sets the right available and used' do
        @subject.available.should == 2
        @subject.used.should == 1
        @subject.available_uids.should == [2,3]
        @subject.used_uids.should == [1]
      end
      it 'releases the right uid' do
        @subject.release @uid
        @subject.available.should == 3
        @subject.used.should == 0
        @subject.available_uids.should == [1,2,3]
        @subject.used_uids.should == []
      end
      it 'does not release the wrong uid' do
        @subject.release @uid + 1
        @subject.available.should == 2
        @subject.used.should == 1
        @subject.available_uids.should == [2,3]
        @subject.used_uids.should == [1]
      end
    end

    describe '#release_all' do
      before do
        @subject.release_all
        3.times { @subject.lock }
      end
      it 'passes sanity tests' do
        @subject.available.should == 0
        @subject.used.should == 3
        @subject.available_uids.should == []
        @subject.used_uids.should == [1,2,3]
      end
      it 'works' do
        @subject.release_all
        @subject.available.should == 3
        @subject.used.should == 0
        @subject.available_uids.should == [1,2,3]
        @subject.used_uids.should == []
      end
    end
  end
end