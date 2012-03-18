require './boot'

class Api < Goliath::API

  def response(env)
    status = 500
    result = 'fail'

    connection_pool do |connection|
      begin
        RedisLock.new(connection, 'hello', logger: logger) do |lock|
          status = 200
          result = String(lock.lock_id)
        end
      rescue RedisLock::Error => e
        result = String(e.class)
      end
    end

    [ status, { 'Content-Type' => 'text/plain' }, 'hello world!' ]
  end

  private

  def connection_pool
    config['redis-connection-pool'].execute(false) { |c| yield c }
  end

end
