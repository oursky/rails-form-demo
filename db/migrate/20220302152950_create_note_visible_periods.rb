class CreateNoteVisiblePeriods < ActiveRecord::Migration[7.0]
  def change
    create_table :note_visible_periods do |t|
      t.datetime :start, precision: 6
      t.datetime :end, precision: 6
      t.references :note, null: false

      t.timestamps
    end
  end
end
