require './boot'

class Api < Goliath::API

  def response(env)
    status = 500

    connection_pool do |connection|
      begin
        RedisLock.new(connection, 'hello', logger: logger) do

        end
      rescue RedisLock::Error => e

      end
    end

    [ status, { 'Content-Type' => 'text/plain' }, 'hello world!' ]
  end

  private

  def connection_pool
    config['redis-connection-pool'].execute(false) { |c| yield c }
  end

end
