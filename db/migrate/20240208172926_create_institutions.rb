class CreateInstitutions < ActiveRecord::Migration[7.1]
  def change
    create_table :institutions do |t|
      t.string :name, null: false, index: true
      t.string :domain, null: false, index: true
      t.string :identifier, null: false, index: true
      t.boolean :active, null: false, index: true, default: true
      t.boolean :funder, null: false, index: true, default: false
      t.string :country_code, null: false, index: true, default: 'US'
      t.string :sso_entity_id
      t.json :extras

      t.timestamps
    end
  end
end
