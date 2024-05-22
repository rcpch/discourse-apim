# name: discourse-apim
# about: RCPCH API key management
# version: 0.0.1
# authors: Michael Barton, RCPCH
# url: https://github.com/rcpch/discourse-apim

register_svg_icon "server"

after_initialize do
  require_relative "app/controllers/apim_controller.rb"
  require_relative "app/jobs/fetch_monthly_usage_data.rb"

  Discourse::Application.routes.append do
    # Pages
    %w[users u].each do |root_path|
      get "#{root_path}/:username/apim" => "users#show",
        :constraints => {
          username: RouteFormat.username,
        }
    end

    # API
    #  TODO: isolate this as a Rails engine
    get "/apim/credentials/:username" => "apim#list",
    :constraints => {
      username: RouteFormat.username,
    }
  
    post "/apim/credentials/:username/:product" => 'apim#create',
      :constraints => {
        username: RouteFormat.username,
      }
    
    # This is a POST, following the upstream Azure API
    # presumably a protection against XSRF 
    post "/apim/credentials/:username/:product/show" => 'apim#show',
      :constraints => {
        username: RouteFormat.username,
      }
    
    get "/apim/usage" => 'apim#usage',
      :constraints => {
        username: RouteFormat.username,
      }
  end
end
