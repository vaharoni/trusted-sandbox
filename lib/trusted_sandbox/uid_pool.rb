module TrustedSandbox

  # Offers intra-server inter-process pool of Uids. In other words:
  #   - Every server has its own pool. Since Docker containers live within a server, this is what we want.
  #   - Processes within the same server share the pool.
  #
  # Usage:
  #   The following will behave the same when different processes try to perform #lock and #release.
  #
  #   pool = UidPool.new 100, 101
  #   pool.lock
  #   # => 100
  #
  #   pool.lock
  #   # => 101
  #
  #   pool.lock
  #   # => RuntimeError: No available UIDs in the pool. Please try again later.
  #
  #   pool.release(100)
  #   # => 100
  #
  #   pool.lock
  #   # => 100
  #
  #   pool.release_all
  #
  class UidPool

    attr_reader :lock_dir, :master_lock_file, :lower, :upper, :timeout, :retries, :delay

    # @param lower [Integer] lower bound of the pool
    # @param upper [Integer] upper bound of the pool
    # @option timeout [Integer] number of seconds to wait for the lock
    # @option retries [Integer] number of attempts to retry to acquire a uid
    # @option delay [Float] delay between retries
    def initialize(lock_dir, lower, upper, options={})
      @lock_dir = lock_dir
      FileUtils.mkdir_p(lock_dir)

      @master_lock_file = lock_file_path_for('master')
      @lower = lower
      @upper = upper
      @timeout = options[:timeout] || options['timeout'] || 3
      @retries = options[:retries] || options['retries'] || 5
      @delay = options[:delay] || options['delay'] || 0.5
    end

    def inspect
      "#<TrustedSandbox::UidPool used: #{used}, available: #{available}, used_uids: #{used_uids}>"
    end

    # Locks one UID from the pool, in a cross-process atomic manner
    # @return [Integer]
    # @raise [PoolTimeoutError] if no ID is available after retries
    def lock
      retries.times do
        atomically(timeout) do
          uid = available_uid
          if uid
            lock_uid uid
            return uid.to_i
          end
        end
        sleep(delay)
      end
      raise PoolTimeoutError.new('No available UIDs in the pool. Please try again later.')
    end

    # Releases all UIDs
    # @return [UidPool] self
    def release_all
      all_uids.each do |uid|
        release uid
      end
      self
    end

    # Releases one UID
    # @param uid [Integer]
    # @return [Integer] UID removed
    def release(uid)
      atomically(timeout) do
        release_uid uid
      end
    end

    # @return [Integer] number of used UIDs
    def used
      used_uids.length
    end

    # @return [Integer] number of availabld UIDs
    def available
      available_uids.length
    end

    # @return [Array<Integer>] all taken uids
    def used_uids
      uids = Dir.entries(lock_dir) - %w(. .. master)
      uids.map(&:to_i)
    end

    # @return [Array<Integer>] all non taken uids
    def available_uids
      all_uids - used_uids
    end

    private

    # @return [Array<Integer>] all uids in range
    def all_uids
      [*lower..upper]
    end

    # @param uid [Integer]
    # @return [String] full path for the UID lock file
    def lock_file_path_for(uid)
      File.join lock_dir, uid.to_s
    end

    # Creates a UID lock file in the lock_dir
    #
    # @param uid [Integer]
    # @return [Integer] the UID locked
    def lock_uid(uid)
      File.open lock_file_path_for(uid), 'w'
      uid
    end

    # Removes a UID lock file from the lock_dir
    #
    # @param uid [Integer]
    # @return [Integer] the UID removed
    def release_uid(uid)
      FileUtils.rm lock_file_path_for(uid), force: true
      uid
    end

    # @param timeout [Integer]
    # @return yield return value
    def atomically(timeout)
      Timeout.timeout(timeout) do
        File.open(master_lock_file, File::RDWR|File::CREAT, 0644) do |f|
          f.flock File::LOCK_EX
          yield
        end
      end
    end

    # @return [Integer, nil] one available uid or nil if none is available
    def available_uid
      available_uids.first
    end

  end
end