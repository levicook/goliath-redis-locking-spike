class RedisLock

  class Error < StandardError ; end
  class Retry < StandardError ; end

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

    self.retries  = options[:retries]  || 2   # count the initial attempt

    self.timeout  = options[:timeout]  || 60  # seconds
    self.sleep    = options[:sleep]    || 0.1 # seconds
    self.stop_at  = now + timeout

    begin
      debug("locking")

      raise RedisLock::TimeoutExceeded if stop_at < now

      if lock_acquired?(generate_expiration_signature)
        begin
          debug("lock acquired")
          yield self
        ensure
          unlock!
          debug("lock released")
        end
      else
        raise RedisLock::Retry
      end
    rescue RedisLock::Retry
      if self.retries <= 0
        raise RedisLock::RetriesExceeded
      else
        self.queue_for_retry
        retry
      end
    end
  end

  def lock_acquired?(signature)
    if redis.setnx(lock_key, signature)
      debug("lock was open and we grabbed it")
      true

    else
      # someone else has the lock, if it has expired,
      # race to grab it, letting redis pick the winner
      # in case there are concurrent getset requests.
      if expired?(redis.get(lock_key))
        if signature == redis.getset(lock_key, signature)
          debug("we won the lock")
          true
        else
          debug("someone else won the lock")
          false
        end
      else
        debug("the open lock hasn't expired")
        false
      end
    end
  end

  def unlock!
    if my_signature?(redis.get(lock_key))
      redis.del(lock_key)
    else
      raise RedisLock::UnlockFailed
    end
  end

  def generate_expiration_signature
    [ (now + timeout + 1) , lock_id ].join(':')
  end

  def expired?(signature)
    signature.nil? || signature.split(':')[0].to_i < now
  end

  def my_signature?(signature)
    signature.split(':')[1] == String(lock_id)
  end

  def now
    Time.now.to_i
  end

  def queue_for_retry
    self.retries -= 1

    # TODO consider binary or exponential backoff on self.sleep
    if defined?(EM::Synchrony)
      EM::Synchrony.sleep(self.sleep)
    else
      Kernel.sleep(self.sleep)
    end
  end

  def debug(message)
    if logger && logger.debug?
      logger.debug(RedisLock: {
        lock_id: lock_id,
        message: message,
      })
    end
  end

end
