require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/dashboard/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create_messages" do
    it "returns http success" do
      get "/dashboard/create_messages"
      expect(response).to have_http_status(:success)
    end
  end

end
