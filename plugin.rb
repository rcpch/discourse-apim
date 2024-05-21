# name: discourse-apim
# about: RCPCH API key management
# version: 0.0.1
# authors: Michael Barton, RCPCH
# url: https://github.com/rcpch/discourse-apim

register_svg_icon "server"

after_initialize do
  require_relative "app/controllers/api_keys_controller.rb"

  Discourse::Application.routes.append do
    %w[users u].each do |root_path|
      get "#{root_path}/:username/api-keys.json" => "apikeys#list",
        :constraints => {
          username: RouteFormat.username,
        }

      get "#{root_path}/:username/api-keys" => "users#show",
        :constraints => {
          username: RouteFormat.username,
        }
      
      post "#{root_path}/:username/api-keys/:product" => 'apikeys#create',
        :constraints => {
          username: RouteFormat.username,
        }
      
      # This is a POST, following the upstream Azure API
      # presumably a protection against XSRF 
      post "#{root_path}/:username/api-keys/:product/keys" => 'apikeys#show',
        :constraints => {
          username: RouteFormat.username,
        }
      
      get "#{root_path}/:username/api-keys/usage" => 'apikeys#usage',
        :constraints => {
          username: RouteFormat.username,
        }
    end
  end
end
