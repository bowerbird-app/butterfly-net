# frozen_string_literal: true

# Controller for testing error capture in integration tests
class TestErrorsController < ApplicationController
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

  def success
    render plain: "OK"
  end
end
