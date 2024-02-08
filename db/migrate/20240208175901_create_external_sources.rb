class CreateExternalSources < ActiveRecord::Migration[7.1]
  def change
    create_table :external_sources do |t|
      t.string name, index: true, nil: false
      t.string download_uri
      t.json last_file_metadata
      t.datetime last_file_fetched_at
      t.timestamps
    end
  end
end
