# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class UserFieldFunction < Function
    def initialize(user_field, user_id)
      @user_field_options = []
      @user_field = user_field
      @user_field_object = UserField.find_by(name: user_field)
      @user_field_id = @user_field_object.id
      @user_field_type = @user_field_object.field_type_enum
      if @user_field_type == "dropdown"
        UserFieldOption.where(user_field_id: @user_field_id).each do |option|
          @user_field_options << option.value
        end
      end
      @function_name = user_field.downcase.gsub(" ", "_")
      @user_custom_field_name = "user_field_#{@user_field_id}"
      @user_id = user_id
      super()
    end

    def name
      I18n.t("chatbot.prompt.function.user_information.name", user_field: @function_name)
    end

    def description
      case @user_field_type
      when "confirm"
        I18n.t("chatbot.prompt.function.user_information.description.confirmation", user_field: @user_field)
      else
        I18n.t("chatbot.prompt.function.user_information.description.general", user_field: @user_field)
      end
    end

    def parameters
      case @user_field_type
      when "text"
        [
          { name: "answer", type: String, description: I18n.t("chatbot.prompt.function.user_information.parameters.answer.text", user_field: @user_field) } ,
        ]
      when "confirm"
        [
          { name: "answer", type: String, enum: ["true", "false"], description: I18n.t("chatbot.prompt.function.user_information.parameters.answer.confirmation", user_field: @user_field) } ,
        ]
      when "dropdown"
        [
          { name: "answer", type: String, enum: @user_field_options, description: I18n.t("chatbot.prompt.function.user_information.parameters.answer.dropdown", user_field: @user_field, options: @user_field_options) } ,
        ]
      end
    end

    def required
      ['answer']
    end

    def process(args)
      begin
        super(args)
        ucf = ::UserCustomField.where(user_id: @user_id, name: @user_custom_field_name).first

        if ucf
          ucf.value = args[parameters[0][:name]]
          ucf.save!
        else
          ::UserCustomField.create!(user_id: @user_id, name: @user_custom_field_name, value: args[parameters[0][:name]])
        end

      rescue StandardError => e
        Rails.logger.error("Chatbot: Error occurred while attempting to store answer in a User Custom Field: #{e.message}")
        I18n.t("chatbot.prompt.function.user_information.error", user_field: @user_field, answer: args[parameters[0][:name]])
      end
    end
  end
end
