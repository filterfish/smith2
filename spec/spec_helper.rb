# require File.expand_path("../../lib/smith", __FILE__)

def set_env_for_block(env_var, value)
  old_value = ENV.delete(env_var)
  ENV[env_var] = value.to_s if value
  yield
  ENV[env_var] = old_value
end

def unset_env_for_block(env_var, &blk)
  set_env_for_block(env_var, nil, &blk)
end
