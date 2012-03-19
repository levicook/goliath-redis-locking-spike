class RedisLock

  class Error < StandardError ; end
  class Retry < StandardError ; end

  class TimeoutExceeded < RedisLock::Error ; end
  class RetriesExceeded < RedisLock::Error ; end

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

    self.retries  = options[:retries]  || 10 # count the initial attempt

    self.timeout  = options[:timeout]  || 2.0 # seconds
    self.sleep    = options[:sleep]    || 0.2 # seconds
    self.stop_at  = now + timeout

    begin
      raise RedisLock::TimeoutExceeded if stop_at < now
      if lock_acquired?(generate_expiration_signature)
        begin
          yield self
        ensure
          unlock!
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
      # debug("lock was open and we grabbed it")
      true

    else
      # someone else has the lock
      # try to replace it with our signature if theirs is expired.

      lockers_signature = redis.get(lock_key)

      if expired?(lockers_signature)

        # we get their signature back, if we successfully replaced it
        if lockers_signature == redis.getset(lock_key, signature)
          # debug("we won the lock")
          true
        else
          # debug("someone else won the lock")
          false
        end
      else
        # debug("the open lock hasn't expired")
        false
      end
    end
  end

  def unlock!
    lockers_signature = redis.get(lock_key)
    redis.del(lock_key) if mine?(lockers_signature)
  end

  def generate_expiration_signature
    [ (now + timeout + 1) , lock_id ].join(':')
  end

  def expired?(signature)
    # debug(expired?: signature)
    !signature.nil? && signature.split(':')[0].to_i < now
  end

  def mine?(signature)
    # debug(mine?: signature)
    !signature.nil? && signature.split(':')[1] == String(lock_id)
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
    logger.debug(RedisLock: { lock_id => message }) if logger && logger.debug?
  end

end
