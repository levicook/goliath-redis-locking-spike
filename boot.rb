require 'bundler/setup'
Bundler.require

#require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'

Kernel.autoload :RedisLock , './lib/redis_lock.rb'
