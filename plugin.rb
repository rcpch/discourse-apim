# name: discourse-apim
# about: RCPCH API key management
# version: 0.0.1
# authors: Michael Barton, RCPCH
# url: https://github.com/rcpch/discourse-apim

register_asset "stylesheets/user-apim.scss"

register_svg_icon "server"

after_initialize do
  require_relative "app/controllers/apim_controller.rb"
  require_relative "app/controllers/apim_usage_controller.rb"
  require_relative "app/jobs/fetch_monthly_usage_data.rb"

  add_admin_route "admin.apim", "apim"

  Discourse::Application.routes.append do
    # Pages
    %w[users u].each do |root_path|
      get "#{root_path}/:username/apim" => "users#show",
        :constraints => {
          username: RouteFormat.username,
        }
    end

    get "/admin/plugins/apim" => "admin/plugins#index",
      :constraints => StaffConstraint.new

    # User API
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
    
    # Admin API
    get "/apim/usage/report" => 'apim_usage#report'
    
    post "/apim/usage/refresh" => 'apim_usage#refresh'
  end
end
