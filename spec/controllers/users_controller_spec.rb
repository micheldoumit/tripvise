require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  describe '#show' do
    before do
      @user = create(:user)
      header(token: @user.fb_token)
      @trip = create(:trip)
    end

    context 'with valid data' do
      it 'responds with 200' do
        get :index, trip_code: @trip.code.code
        expect(response).to have_http_status(:ok)
      end

      it 'returns the owner of the trip' do
        get :index, trip_code: @trip.code.code
      end
    end

    context 'with invalid data' do
      it 'responds with 400' do
        get :index, trip_code: 'INVALID'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe '#create' do
    before do
      header(token: user_json[:fb_token])
      post :create, format: :json, user: user_json
    end
    let(:json) { JSON.parse(response.body) }

    context 'with valid data' do
      let(:user_json) { attributes_for(:user) }

      it 'responds with 200' do
        expect(response).to have_http_status :ok
      end

      it 'creates a user' do
        expect do
          post :create, user: attributes_for(:user_recommender)
        end.to change(User, :count).by(1)
      end

      it 'has a profile profile_picture' do
        expect(json['user']['profile_picture']).to_not be_nil
      end
    end

    context 'with invalid data' do
      let(:user_json) { attributes_for(:invalid_user) }

      it 'responds with 400' do
        expect(response).to have_http_status :bad_request
      end

      it 'doens\'t create a user' do
        expect(User.all).to be_empty
      end
    end

    context 'with duplicated email' do
      let(:user_json) { attributes_for(:user) }

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

  describe '#send_email' do
    let(:user) { create(:user) }

    before do
      header(token: user[:fb_token])
    end

    context 'with not invited friend' do
      let(:trip_code) { create(:code) }
      let(:friend) { create(:user) }
      let(:recommender) do
        Recommender.find_by(user: friend)
      end

      before do
        post :send_email, format: :json, id: user[:id],
                          trip_code: trip_code.code,
                          fb_ids: [friend.fb_id]
      end

      it 'responds with 204' do
        expect(response).to have_http_status :no_content
      end

      it 'creates the recommender' do
        expect(recommender).to_not be_nil
      end

      it 'creates for correct trip' do
        expect(recommender.trip).to eq trip_code.trip
      end

      it 'creates for correct friend' do
        expect(recommender.user).to eq friend
      end

      it 'creates for correct code' do
        expect(recommender.code).to eq trip_code
      end
    end

    context 'existing registered friend' do
      let(:trip_code) { create(:code) }
      let(:friend) { create(:user) }

      before do
        create(:recommender, trip_id: trip_code.trip.id, code_id: trip_code.id, user_id: friend.id)
        post :send_email, format: :json, id: user[:id],
                          trip_code: trip_code.code,
                          fb_ids: [friend.fb_id]
      end

      it 'responds with 204' do
        expect(response).to have_http_status :no_content
      end

      it 'does not duplicate the recommender' do
        expect(Recommender.where(user: friend).count).to eq 1
      end
    end

    context 'with invalid data' do
      before do
        post :send_email, format: :json, id: user[:id],
                          trip_code: trip_code,
                          fb_ids: fb_ids
      end
      let(:user) { create(:user) }
      let(:trip_code) { 'INVALID' }
      let(:fb_ids) { nil }

      it 'responds with 400' do
        expect(response).to have_http_status :bad_request
      end
    end
  end

  describe '#redeem' do
    before do
      header(token: user[:fb_token])
      post :redeem, format: :json, id: user[:id],
                    trip_code: trip_code
    end

    context 'with valid data' do
      let(:user) { create(:user) }
      let(:trip_code) { create(:code).code }

      it 'responds with 400' do
        expect(response).to have_http_status :no_content
      end
    end

    context 'with invalid data' do
      let(:user) { create(:user) }
      let(:trip_code) { 'INVALID' }

      it 'responds with 400' do
        expect(response).to have_http_status :bad_request
      end
    end
  end

  describe '#recommendation_requests' do
    before do
      allow_any_instance_of(Koala::Facebook::API).to \
        receive(:get_connections).and_return(fb_friends)

      if create_recommender?
        trip = create(:trip, user: create(:user_recommender))
        Recommender.create(
          trip: trip,
          user: user,
          code: Code.find_by(trip: trip)
        )
      end
      header(token: user[:fb_token])
    end
    let(:fb_user) { { 'name' => 'FB Friend', 'id' => '633177910141622' } }
    let(:fb_friends) { [fb_user] }

    context 'with valid data' do
      let(:user) { create(:user) }
      let(:create_recommender?) { true }

      it 'responds with 200' do
        get :recommendation_requests, format: :json, id: user[:id]
        expect(response).to have_http_status :ok
      end

      context 'JSON response' do
        before do
          get :recommendation_requests, format: :json, id: user[:id]
        end

        it 'has a list of objects' do
          expect(json).to_not be_nil
        end

        it 'has an associated user' do
          expect(json['recommendation_requests'].first['user']).to_not be_nil
        end

        it 'has an associated trip' do
          expect(json['recommendation_requests'].first['trip']).to_not be_nil
        end

        it 'has a recommendation_type' do
          expect(json['recommendation_requests'].first['trip']['recommendation_type']).to_not be_nil
        end
      end

      context 'when a additional recommenders needs to be created to a non private trip' do
        before do
          create(:not_private_trip)
        end

        it 'must have 2 recommenders in the response' do
          get :recommendation_requests, format: :json, id: user[:id]
          expect(json['recommendation_requests'].size).to eq 2
        end
      end

      context 'when a friend has a private trip' do
        before do
          create(:trip, user: create(:user, fb_id: fb_user['id']))
        end

        it 'must have 1 recommender in the response' do
          get :recommendation_requests, format: :json, id: user[:id]
          expect(json['recommendation_requests'].size).to eq 1
        end
      end

      context 'when the recommender is already created' do
        before do
          trip_from_friend = create(:not_private_trip)
          Recommender.create(
          trip: trip_from_friend,
          user: user,
          code: Code.find_by(trip: trip_from_friend)
          )
        end

        it 'not duplicates the existing recommender' do
          get :recommendation_requests, format: :json, id: user[:id]
          expect(json['recommendation_requests'].size).to eq 2
        end
      end
    end

    context 'with invalid data' do
      let(:user) { build(:user, id: 10_000, fb_token: '123123A') }
      let(:create_recommender?) { false }

      it 'responds with 401' do
        get :recommendation_requests, format: :json, id: user[:id]
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe '#my_recommendations' do
    before do
      if create_recommendation?
        create(:recommendation, recommender: user, trip: trip)
        create(:recommendation, recommender: user, trip: create(:trip, user: user))
      end

      header(token: user[:fb_token])
      get :my_recommendations, format: :json, id: user[:id],
                               trip_id: trip[:id]
    end

    context 'with valid data' do
      let(:user) { create(:user) }
      let(:trip) { create(:trip, user: user) }
      let(:create_recommendation?) { true }

      it 'responds with 200' do
        expect(response).to have_http_status :ok
      end

      context 'JSON response' do
        it 'has a list of objects' do
          expect(json).to_not be_nil
        end

        it 'has a user' do
          expect(json['recommendations'].first['user']).to_not be_nil
        end

        it 'has a trip' do
          expect(json['recommendations'].first['trip']).to_not be_nil
        end

        it 'has a place' do
          expect(json['recommendations'].first['place']).to_not be_nil
        end

        it 'has recommendations' do
          expect(json['recommendations']).to_not be_nil
        end

        it 'has only one recommendation' do
          expect(json['recommendations'].count).to eq(1)
        end

        it 'belongs to the same trip' do
          json['recommendations'].each do |recommendation|
            expect(recommendation['trip']['id']).to eq(trip.id)
          end
        end

        it 'has an expedia link' do
          expect(json['recommendations'].first['expedia_url']).to_not be_nil
        end

        it 'has a tripadvisor link' do
          expect(json['recommendations'].first['tripadvisor_url']).to_not be_nil
        end

        it 'has a recommendation_type' do
          expect(json['recommendations'].first['recommendation_type']).to_not be_nil
        end
      end
    end

    context 'with invalid data' do
      let(:user) { build(:user, id: 10_000, fb_token: '123123A') }
      let(:trip) { create(:trip) }
      let(:create_recommendation?) { false }

      it 'responds with 401' do
        expect(response).to have_http_status :unauthorized
      end
    end
  end
end
