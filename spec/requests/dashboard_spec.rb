require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /messages" do
    it "returns http success" do
      post dashboard_messages_path
      expect(response).to have_http_status(:success)
    end
  end
end
