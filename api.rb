require './boot'

class Api < Goliath::API

  def response(env)
    result = 'a'

    connection_pool do |connection|
      begin
        RedisLock.new(connection, 'hello', logger: logger) do |lock|
          result = 'ab'
        end
      rescue RedisLock::TimeoutExceeded
        result = 'abc'
      rescue RedisLock::RetriesExceeded
        result = 'abcd'
      rescue RedisLock::UnlockFailed
        result = 'abcde'
      end
    end

    [ 200, { 'Content-Type' => 'text/plain' }, result ]
  end

  private

  def connection_pool
    config['redis-connection-pool'].execute(false) { |c| yield c }
  end

end
