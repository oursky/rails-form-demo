class Note < ApplicationRecord
  belongs_to :author

  has_many :note_visible_periods, dependent: :destroy

  def visible?(at: DateTime.now)
    note_visible_periods.size == 0 ||
      note_visible_periods.where(start: ..at, end: at..).size > 0
  end

  def next_visible_period(since: DateTime.now)
    return nil if note_visible_periods.size == 0
    note_visible_periods.where(start: since..).order(:start).first
  end
end
