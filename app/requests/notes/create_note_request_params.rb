module Notes
  class CreateNoteVisiblePeriodRequestParams < BaseRequestParams
    attribute :start_date, :date
    attribute :start_time, :time, default: Time.now.beginning_of_day
    attribute :end_date, :date
    attribute :end_time, :time, default: Time.now.beginning_of_day

    validates :start_date, presence: true
    validates :end_date, presence: true

    validate :valid_time_order, if: -> { start_date.present? && end_date.present? }

    def start_date_time; combine_date_time(start_date, start_time) end
    def end_date_time; combine_date_time(end_date, end_time) end

    def valid_time_order
      errors.add(:end_time, :earlier_than_start) if start_date_time > end_date_time
    end

    private

    def combine_date_time(date, time)
      DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
    end
  end

  class CreateNoteRequestParams < BaseRequestParams
    attribute :content, :string
    attribute :author_name, :string

    attribute :visible_periods, default: []

    association :visible_periods, CreateNoteVisiblePeriodRequestParams, array: true

    validates :content, presence: true
    validates :author_name, presence: true

    def save
      return false unless valid?
      timeslots = visible_periods.map do |period|
        NoteVisiblePeriod.new(
          start: period.start_date_time,
          end: period.end_date_time
        )
      end
      Note.create(
        content: content,
        author: Author.find_or_create_by(name: author_name),
        note_visible_periods: timeslots
      )
    end
  end
end
