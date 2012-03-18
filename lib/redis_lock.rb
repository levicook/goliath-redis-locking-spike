class RedisLock

  class Error                < StandardError    ; end
  class TimeoutExceededError < RedisLock::Error ; end
  class RetriesExceededError < RedisLock::Error ; end
  class UnlockFailedError    < RedisLock::Error ; end

  attr_accessor :redis, :logger
  attr_accessor :lock_id, :lock_key, :retries, :timeout

  def initialize(redis, key, options={}, &block)
    raise RedisLock::Error, 'Invalid key' if key.nil?

    self.redis  = redis
    self.logger = options[:logger]

    self.lock_id  = options[:lock_id]  || redis.incr('redis-lock:lock-id')
    self.lock_key = options[:lock_key] || [ 'redis-lock:lock', key ].join(':')
    self.retries  = options[:retries]  || 99  # doesn't count the initial attempt
    self.timeout  = options[:timeout]  || 60  # seconds
    self.sleep    = options[:sleep]    || 0.1 # seconds

    begin
      lock!
      yield
    ensure
      unlock!
    end
  end

  private

  def lock!
    # debug!

    begin
      signature = generate_expiration_signature

      # lock might be open, grab it if we can
      return if redis.setnx(lock_key, signature)

      # okay, lock is being held ... if it's expired, use getset to acquire it
      if expired?(redis.get(lock_key))
        if signature == redis.getset(lock_key, signature)
          return
        else
          # somebody else got the lock
        end
      else
        # the open lock hasn't expired yet
      end

      raise "Unable to acquire lock for #{key}."
    rescue => e
      if e.message == "Unable to acquire lock for #{key}."
        if attempt_counter == max_attempts
          raise
        else
          attempt_counter += 1
          sleep 1
          retry
        end
      else
        raise
      end
    end
  end

  def unlock!
  end

  def generate_expiration_signature
    [ (Time.now.to_i + self.timeout + 1) , self.lock_id ].join(':')
  end

  def expired?(signature)
    Integer(signature.split(':').shift) < Time.now.to_i
  end

  def debug!
    logger.debug(RedisLock: {
      lock_id: self.lock_id,
      retries: self.retries,
      timeout: self.timeout,
    }) if logger && logger.debug?
  end

end
