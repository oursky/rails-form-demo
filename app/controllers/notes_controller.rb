class NotesController < ApplicationController
  before_action -> { @request_params_cls = Notes::CreateNoteRequestParams }
  before_action -> { @request_params = @request_params_cls.new }
  before_action -> { @request_params << form_params }, only: %i[create]

  def index; end

  def create
    action = params[:button].presence || ''
    return add_timeslot if action == 'add_timeslot'
    return delete_timeslot(action.split(':')[1].to_i) if action.starts_with?('delete_timeslot:')

    return render 'update_form', format: :turbo_stream unless @request_params.save

    redirect_to notes_path
  end

  private

  def form_params
    params.require(@request_params_cls.model_name.param_key)
  end

  def add_timeslot
    @request_params.visible_periods << Notes::CreateNoteVisiblePeriodRequestParams.new
    render 'update_form', format: :turbo_stream
  end

  def delete_timeslot(index)
    @request_params.visible_periods.delete_at(index)
    render 'update_form', format: :turbo_stream
  end
end
