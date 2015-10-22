json.array!(@projects) do |project|
  json.extract! project, :id, :name, :desc, :download_url, :app_id, :icon
  json.url project_url(project, format: :json)
end
