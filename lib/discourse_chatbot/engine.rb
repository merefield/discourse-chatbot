# frozen_string_literal: true
module ::DiscourseChatbot
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseChatbot
    config.autoload_paths << File.join(config.root, "lib")
  end
end
