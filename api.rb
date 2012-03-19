require './boot'

class Api < Goliath::API

  def response(env)
    result, status = 'a', 500

    connection_pool do |connection|
      begin
        RedisLock.new(connection, 'hello', logger: logger) do |lock|
          result, status = 'ab', 200
        end
      rescue RedisLock::TimeoutExceeded
        result, status = 'abc', 200
      rescue RedisLock::RetriesExceeded
        result, status = 'abcd', 200
      end
    end

    [ status , { 'Content-Type' => 'text/plain' } , result ]
  end

  private

  def connection_pool
    config['redis-connection-pool'].execute(false) { |c| yield c }
  end

end
