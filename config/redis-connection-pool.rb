redis_environment = String(Goliath.env)
redis_config_file = File.expand_path('../config/redis.yml', __FILE__)
redis_config_yaml = YAML.load_file(redis_config_file)

redis_config = redis_config_yaml[redis_environment]
redis_config.symbolize_keys!

pool_size = redis_config.delete(:pool) || 1

config['redis-connection-pool'] = EM::Synchrony::ConnectionPool.new(size: pool_size) do
  Redis.new(redis_config)
end
