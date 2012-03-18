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
    ensure
      unlock!
    end
  end

  private

  def lock!
    begin
      raise RedisLock::TimeoutExceeded if timeout_exceeded?
      if lock_acquired?(generate_expiration_signature)
        yield
      else
        raise RedisLock::ConsiderRetry
      end
    rescue RedisLock::ConsiderRetry
      raise RedisLock::RetriesExceeded if self.retries <= 0
      self.retries -= 1
      self.sleep!
      retry
    end
  end

  def lock_acquired?(signature)
    if redis.setnx(lock_key, signature)
      true # lock was open and we grabbed it
    else
      # someone else has the lock, if it has expired,
      # race to grab it, letting redis pick the winner
      # in case there are concurrent getset requests.
      if expired?(redis.get(lock_key))
        if signature == redis.getset(lock_key, signature)
          true # we won the lock
        else
          false # somone else won the lock
        end
      else # the open lock hasn't expired yet
        false
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
    # TODO consider binary or exponential backoff
    if defined?(EM::Synchrony)
      EM::Synchrony.sleep(self.sleep)
    else
      Kernel.sleep(self.sleep)
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
