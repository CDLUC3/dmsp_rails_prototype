class CreateInstitutions < ActiveRecord::Migration[7.1]
  def change
    create_table :institutions do |t|
      t.string :label, null: false, index: true
      t.string :identifier, null: false, index: true
      t.boolean :active, null: false, index: true, default: true
      t.boolean :funder, null: false, index: true, default: false
      t.string :country_code, null: false, index: true, default: 'US'
      t.string :description
      t.string :wikipedia_url
      t.json :searchable_names
      t.json :types
      t.json :children
      t.string :parent
      t.json :addresses
      t.json :links
      t.json :aliases
      t.json :acronyms
      t.json :country
      t.json :external_ids
      t.string :source, index: true, default: 'self'
      t.datetime :source_synced_at
      t.timestamps
    end
  end
end
