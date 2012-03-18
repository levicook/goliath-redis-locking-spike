class RedisLock

  class Error         < StandardError ; end
  class ConsiderRetry < StandardError ; end

  class TimeoutExceeded < RedisLock::Error ; end
  class RetriesExceeded < RedisLock::Error ; end

  class UnlockFailed    < RedisLock::Error ; end

  attr_accessor :redis, :logger
  attr_accessor :lock_id, :lock_key
  attr_accessor :retries
  attr_accessor :timeout, :sleep, :stop_at

  def initialize(redis, key, options={}, &block)
    raise RedisLock::Error, 'Invalid key' if key.nil?

    self.redis  = redis
    self.logger = options[:logger]

    self.lock_id  = options[:lock_id]  || redis.incr('redis-lock:lock-id')
    self.lock_key = options[:lock_key] || [ 'redis-lock:lock', key ].join(':')

    self.retries  = options[:retries]  || 99  # doesn't count the initial attempt

    self.timeout  = options[:timeout]  || 60  # seconds
    self.sleep    = options[:sleep]    || 0.1 # seconds
    self.stop_at  = now + timeout

    begin
      lock!
      yield
    ensure
      unlock!
    end
  end

  private

  def lock!
    begin
      debug!
      raise RedisLock::TimeoutExceeded if timeout_exceeded?

      signature = generate_expiration_signature

      # lock might be open, grab it if we can
      return if redis.setnx(lock_key, signature)

      # lock is being held
      # if it's expired, use getset to acquire it
      if expired?(redis.get(lock_key))
        if signature == redis.getset(lock_key, signature)
          return
        else
          # somebody else won the lock
        end
      else
        # the open lock hasn't expired yet
      end

      raise RedisLock::ConsiderRetry

    rescue RedisLock::ConsiderRetry

      if self.retries <= 0
        raise RedisLock::RetriesExceeded

      else
        self.retries -= 1
        self.sleep!
        retry

      end
    end
  end

  def unlock!
    # make sure it's my lock
  end

  def timeout_exceeded?
    stop_at < now
  end

  def generate_expiration_signature
    [ (now + timeout + 1) , lock_id ].join(':')
  end

  def expired?(signature)
    signature.split(':').shift.to_i < now
  end

  def now
    Time.now.to_i
  end

  def sleep!
    if defined?(EM::Synchrony)
      EM::Synchrony.sleep(sleep)
    else
      Kernel.sleep(sleep)
    end
  end

  def debug!
    logger.debug(RedisLock: {
      lock_id:  lock_id,
      lock_key: lock_key,
      retries:  retries,
      now:      now,
      stop_at:  stop_at,
    }) if logger && logger.debug?
  end

end
