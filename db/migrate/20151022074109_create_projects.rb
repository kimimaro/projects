class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :name
      t.string :desc
      t.string :download_url
      t.string :app_id
      t.string :icon

      t.timestamps
    end
  end
end
