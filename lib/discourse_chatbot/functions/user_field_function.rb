# frozen_string_literal: true

require_relative '../function'

module DiscourseChatbot
  class UserFieldFunction < Function
    def initialize(user_field, user_id)
      super()
      @user_field = user_field
      @function_name = user_field.downcase.gsub(" ", "_")
      @user_custom_field_name = "user_field_#{UserField.find_by(name: user_field).id}" 
      @user_id = user_id
    end

    def name
      I18n.t("chatbot.prompt.function.user_information.name", user_field: @function_name)
    end

    def description
      I18n.t("chatbot.prompt.function.user_information.description", user_field: @user_field)
    end

    def parameters
      [
        { name: "answer", type: String, description: I18n.t("chatbot.prompt.function.user_information.parameters.answer") } ,
      ]
    end

    def required
      ['answer']
    end

    def process(args)
      begin
        super(args)

        # ::UserField.find_by(name: @user_field) = args[parameters[0][:name]]
        ucf = ::UserCustomField.where(user_id: @user_id, name: @user_custom_field_name).first
        if ucf
          ucf.value = args[parameters[0][:name]]
          ucf.save!
        else
          ::UserCustomField.create!(user_id: @user_id, name: @user_custom_field_name, value: args[parameters[0][:name]])
        end

        
        #, value: args[parameters[0][:name]]}, on_duplicate: :update, unique_by: [:user_id, :name])
        #::UserCustomField.upsert({user_id: @user_id, name: @user_field, value: args[parameters[0][:name]]}, on_duplicate: :update, unique_by: [:user_id, :name])

      rescue StandardError => e
        Rails.logger.error("Chatbot: Error occurred while attempting to store answer in a User Custom Field: #{e.message}")
        I18n.t("chatbot.prompt.function.user_information.error", user_field: @user_field, answer: args[parameters[0][:name]])
      end
    end
  end
end
