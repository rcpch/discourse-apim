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

    %w[groups g].each do |root_path|
      resources :groups,
                only: %i[index show new edit update],
                id: RouteFormat.username,
                path: root_path do
        member do
          %w[
            apim
          ].each { |path| get path => "groups#show" }
        end
      end
    end

    get "/admin/plugins/apim" => "admin/plugins#index",
      :constraints => StaffConstraint.new

    # User API
    #  TODO: isolate this as a Rails engine
    get "/apim/users/:username/credentials" => "apim#list_for_user",
    :constraints => {
      username: RouteFormat.username,
    }

    get "/apim/groups/:id" => "apim#list_for_group"
  
    post "/apim/users/:username/products/:product" => 'apim#create_for_user',
      :constraints => {
        username: RouteFormat.username,
      }

    post "/apim/groups/:id/products/:product" => 'apim#create_for_group'
    
    # This is a POST, following the upstream Azure API
    # presumably a protection against XSRF 
    post "/apim/users/:username/products/:product/showCredentials" => 'apim#show_for_user',
      :constraints => {
        username: RouteFormat.username,
      }

    post "/apim/groups/:id/products/:product/showCredentials" => 'apim#show_for_group'
    
    # Admin API
    get "/apim/usage/report" => 'apim_usage#report'
    
    post "/apim/usage/refresh" => 'apim_usage#refresh'
  end

  register_user_custom_field_type('apim', :json)
  register_group_custom_field_type('apim', :json)
end
