class ApikeysController < ::ApplicationController
  def create
    fake_api_key = {}
    fake_api_key['product'] = 'Growth Charts'
    fake_api_key['key'] = params[:username]

    ret = {}
    ret['api_keys'] = [fake_api_key]

    render json: ret
  end
end