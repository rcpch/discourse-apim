# name: discourse-apim
# about: RCPCH API key management
# version: 0.0.1
# authors: Michael Barton, RCPCH
# url: https://github.com/rcpch/discourse-apim

register_svg_icon "server"

after_initialize do
  Discourse::Application.routes.append do
    %w[users u].each do |root_path|
      get "#{root_path}/:username/api-keys" => "users#show",
        :constraints => {
          username: RouteFormat.username,
        }
    end
  end
end
