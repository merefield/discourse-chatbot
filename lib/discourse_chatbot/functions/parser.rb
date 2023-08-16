# frozen_string_literal: true
require 'json'

module ::DiscourseChatbot
  class Parser
    def self.type_mapping(dtype)
      case dtype.to_s
      when "Float"
        'number'
      when "Integer"
        'integer'
      when "Numeric"
        'number'
      when "String"
        'string'
      else
        'string'
      end
    end

    def self.extract_params(doc_str)
      params_str = doc_str.split("\n").reject(&:strip_empty?)
      params = {}
      params_str.each do |line|
        if line.strip.start_with?(':param')
          param_match = line.match(/(?<=:param )\w+/)
          if param_match
            param_name = param_match[0]
            desc_match = line.gsub(":param #{param_name}:", "").strip
            params[param_name] = desc_match unless desc_match.empty?
          end
        end
      end
      params
    end

    def self.func_to_json(func)
       params = {}
       func.parameters.each do |param|
        params.merge!("#{param[:name]}": {})
        
        params[:"#{param[:name]}"].merge!("type": type_mapping(param[:type]).to_s)
        params[:"#{param[:name]}"].merge!("description": param[:description])
       end
       params = JSON.parse(params.to_json)

      func_json = {
        'name' => func.name,
        'description' => func.description,
        'parameters' => {
          'type' => 'object',
          'properties' => params,
          'required' => func.required
        }
      }
    end
  end
end
