# frozen_string_literal: true

# Controller for testing error capture in integration tests
class TestErrorsController < ApplicationController
  skip_before_action :allow_browser, raise: false

  def index; end

  def name_error
    # Simulate uninitialized constant error like "MediaKitsController::MediaKi"
    SomeUndefinedConstant
  end

  def no_method_error
    nil.undefined_method_call
  end

  def argument_error
    raise ArgumentError, "wrong number of arguments (given 1, expected 0)"
  end

  def type_error
    1 + "string"
  end

  def runtime_error
    raise RuntimeError, "Something went wrong"
  end

  def handled_runtime_error
    begin
      raise RuntimeError, "Something handled but important went wrong"
    rescue RuntimeError => error
      ButterflyNet.error(
        error,
        request_id: request.request_id,
        scenario: "handled_runtime_error"
      )
      render plain: "Handled and logged"
    end
  end

  def unhandled_runtime_error
    raise RuntimeError, "Something handled but important went wrong"
  end

  def success
    render plain: "OK"
  end
end
