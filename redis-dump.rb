#! /usr/bin/ruby

require 'rubygems'
require 'redis'
require 'yaml'

REDIS = Redis.new

DUMP_MAP = {
  "string" => "get",
  "list"   => "lrange",
  "set"    => "smembers",
  "zset"   => "zrange",
  "hash"   => "hgetall",
}

def dump(yml_dump_file="redis-dump.yml")
  content_file = File.new(yml_dump_file, "w")
  REDIS.keys.each do |key|
    key_type = REDIS.type key
    if key_type == "list"
      key_content = REDIS.send(DUMP_MAP[key_type], key, 0, -1)
    elsif key_type == "zset"
      keys = REDIS.send(DUMP_MAP[key_type], key, 0, -1)
      key_content = {}
      keys.each{|k| key_content[k] = REDIS.zscore(key, k)}
    else
      key_content = REDIS.send(DUMP_MAP[key_type], key)
    end

    key_obj = {"key_name" => key, "key_type" => key_type, "key_content" => key_content}

    content_file << YAML::dump(key_obj)
  end
  content_file.close
end


def load(yml_dump_file="redis-dump.yml")
  content_file = File.new(yml_dump_file, "r")
  content_file.gets
  while (line = content_file.gets)
    yml_obj = line
    until line == "--- \n" || line.nil?
      yml_obj += line
      line = content_file.gets
    end
    obj = YAML::load yml_obj

    k_name = obj["key_name"]
    k_type = obj["key_type"]
    k_content = obj["key_content"]
    
    case k_type
      when "string"
        REDIS.set k_name, k_content
      when "list"
        k_content.each{|k| REDIS.rpush k_name, k}
      when "set"
        k_content.each{|k| REDIS.sadd k_name, k}
      when "zset"
        k_content.each{|k, v| REDIS.zadd k_name, k, v}
      when "hash"
        REDIS.mapped_hmset k_name, k_content
    end
  end
end
