# frozen_string_literal: true

json.partial! 'api/v1/gym_routes/short_detail', gym_route: gym_route
json.picture gym_route.picture.attached? ? url_for(gym_route.picture) : nil

json.gym_sector do
  json.partial! 'api/v1/gym_sectors/short_detail', gym_sector: gym_route.gym_sector
end

json.tags do
  json.array! gym_route.tags do |tag|
    json.id tag.id
    json.name tag.name
  end
end
json.video_count gym_route.videos.count

json.history do
  json.extract! gym_route, :created_at, :updated_at
end