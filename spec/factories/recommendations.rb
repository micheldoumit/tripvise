FactoryGirl.define do
  factory :recommendation do
    sequence(:id) { |n| n }
    recommender_id { create(:user).id }
    place { build(:place) }
    trip
    description 'Aracaju is a top city man, animal'
    wishlisted true
    rating 'top'
    place_type 'attraction'
    google_places_url 'www.google.com'

    factory :recommendation_json do
      place { attributes_for(:place) }
      recommender_id { create(:user).id }
      trip_id { create(:trip).id }
    end
  end
end
