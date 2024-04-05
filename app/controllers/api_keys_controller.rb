class ApikeysController < ::ApplicationController
  def create
    ret = {}
    ret['username'] = params[:username]

    render json: ret
  end
end