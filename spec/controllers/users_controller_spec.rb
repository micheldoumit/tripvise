require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe '#index' do
    before do
      get :index
    end

    context 'with params' do
      it 'responds with 200' do
        expect(response).to have_http_status :ok
      end
    end
  end

  describe '#create' do
    before do
      post :create, format: :json, user: user
    end

    context 'with valid data' do
      let(:user) { attributes_for(:user) }

      it 'responds with 200' do
        expect(response).to have_http_status :ok
      end

      it 'creates a user' do
        expect(User.all).to_not be_empty
      end
    end

    context 'with invalid data' do
      let(:user) { attributes_for(:invalid_user) }

      it 'responds with 400' do
        expect(response).to have_http_status :bad_request
      end

      it 'doens\'t create a user' do
        expect(User.all).to be_empty
      end
    end

    context 'with duplicated email' do
      let(:user) { attributes_for(:user) }

      it 'responds with 200' do
        expect(response).to have_http_status :ok
      end

      it 'returns user that is already created with that email' do
        duplicated = attributes_for(:duplicated_email)
        post :create, format: :json, user: duplicated

        expect(duplicated[:name]).to eq 'Brad Pitt'
      end
    end
  end
end
