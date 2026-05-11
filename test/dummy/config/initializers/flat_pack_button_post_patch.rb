# frozen_string_literal: true

# Patch FlatPack buttons in the dummy app so non-GET actions submit through
# button_to forms instead of relying on JS link interception.
Rails.application.config.after_initialize do
  next unless defined?(FlatPack::Button::Component)

  FlatPack::Button::Component.class_eval do
    private

    unless private_method_defined?(:original_render_link)
      alias_method :original_render_link, :render_link
    end

    def render_link
      if @method.present? && @method.to_s != "get"
        render_form_button
      else
        original_render_link
      end
    end

    def render_form_button
      button_to @url, method: @method, form_class: "inline", class: button_classes do
        button_content
      end
    end
  end
end
