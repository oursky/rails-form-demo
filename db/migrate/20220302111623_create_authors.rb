class CreateAuthors < ActiveRecord::Migration[7.0]
  def change
    create_table :authors do |t|
      t.string :name

      t.timestamps
    end

    add_reference :notes, :author
  end
end
