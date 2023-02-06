require 'faraday'
require 'json'


module DiscourseOpenAIBot

  class OpenAIBot < StandardError; end

  class OpenAIBot

    # def self.list_games

    #   game_settings = SiteSetting.openai_bot_stories.split('|')
    #   games_list = ""
      
    #   game_settings.each_with_index do |line, index|
    #     game = line.split(',')
    #     games_list +="#{index+1}. #{game[0]}\n"
    #   end

    #   games_list
    # end


    def initialize
     
      # @connection = Faraday.new(url: SiteSetting.openai_bot_base_url)

      @connection = Faraday.new(url: "https://chat.openai.com/backend-api/conversation")
        

      
        # , params: {key: openai_bot_api_key, cb_settings_tweak1: wackiness, cb_settings_tweak2: talkativeness, cb_settings_tweak3: attentiveness})
    end

    def make_get(params)
      api_key = "Bearer #{SiteSetting.openai_bot_api_key}"
      # org = SiteSetting.openai_bot_api_organisation

      # form_data = {
      #   model: "text-davinci-003",
      #   prompt: "Say this is a test",
      #   temperature: 0,
      #   max_tokens: 7
      #  }.to_json


      ## open AI
    #    params = {
    #     "model": SiteSetting.openai_bot_request_model,
    #     "prompt": params[:input],
    #     "temperature": SiteSetting.openai_bot_request_temperature,
    #     "max_tokens": SiteSetting.openai_bot_request_max_tokens
    # }.to_json


      # cookie = 	"eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..1Mgbxsjd4TDra6VR.JOl6knv4MT_jtloDV2VEL2RvMUVEGFcAqG1zetXH-8TaKYCsVRhPxEpT5iNiG5OXFhMZ7sljQjVMkJhWdSMVinmFTIjiQ-ouYa5ADDbR-noT-bLaAfKupSeYx9w7mfzr-ky3NZ1nWje4z9COc252u1T00Zo31iy7CuUtnef2FUErhosvBBqThcxNsc4Hlc9j-j95eikP5Hg81Z-4FEWWwJnS_w6pWNQV_EPckxgDBHkGPxCVkEWV4ZZvrOqhJFjn3VE_FL6F7K6jEvreBRl5AosQlWkNk0Z0kFSG5OziwINXrk9n8D1cKbWEl2uGVSF1J8c8HAZ7wo4PLwUgnZiPl7lSGnLJN4DTxYQXnvbzuJqv09xM9OMZkBThjHcXWUEvDj3pz6pZZAlOiQH_VqrRf_PEsuJdZ-Q6_7lR_J8fhOq1bc-K2Ux39IGEMSUy5CnHfgYuA…cMqBJLciMSF4xvAVWlnfD9vRNWaCQ8cbTag_KgShIzMioX4NX7zLuFcZlQBCK5doBWXZYGseXMWY_8geqrOzU4cD8CG1ITuNWR0RCZ0bN2jfGOoJXohQ1goefAeYECe8FNEPorpsVDcEiGqo_IZoTGjvKVv-xMAJX_3hVYj4NjLaFnq8ZC7c5U6sN9jLo6DzbCRG7dx1aztpKcy9thZVoB9roanzWvVpNL27VNCbStdDNxhl-s8rPKFCqtechwgryvCIOUKcE-cHOjBFkdwVagG5BF0fRU1E538AcIih86TvLavDVGlM7ZWg3mwc4CAk38sEEz3KNGycw1ZQzaLi7w996fNIml8ByzaR123t5st66LuwKZZEcG9U6au32aSQ8pVZRZvzUXP7brhzGv8UA617P2aHHCJEJkqvCQmp1Qb0ap78_IXVrKMW7weF9JbOLWD6bENA4s4IyaUTI564ZhXUo26aIlANlJHXy5I.Z8kKjuijMd-QAxppu-b2aw"
#        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) ",
#         "Version/16.1 Safari/605.1.15",
      header_params = {
        "Host": "chat.openai.com",
        "Accept": "text/event-stream",
        "Authorization": api_key,
        "Content-Type": "application/json",
        "X-Openai-Assistant-App-Id": "",
        "Connection": "close",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://chat.openai.com/chat"
       }


               # "cookie": cookie,
        # "origin": "https://chat.openai.com",
        # "referer": "https://chat.openai.com/chat",
        # "sec-ch-ua": "'Not?A_Brand';v='8', 'Chromium';v='108', 'Google Chrome';v='108'",
        # "sec-ch-ua-mobile": "?0",
        # "sec-ch-ua-platform": "macOS",
        # "sec-fetch-dest": "empty",
        # "sec-fetch-mode": "cors",
        # "sec-fetch-site": "same-origin",
        # "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36",
        # "x-openai-assistant-app-id": ""
       params = {
        "action": "next",
         "messages": [{
           "id": "ffa75905-d80e-4c74-bbd1-7adfe6ba523e",
           "role": "user",
           "content": {"content_type": "text", "parts": params[:input].split(" ")}
          }],
       "conversation_id": "ab21dc8c-39d4-4589-90b6-ff5c5af364e3",
       "parent_message_id": "577372cf-a7f5-425e-8723-5d46bb98b7b0",
       "model": "text-davinci-002-render"
      }.to_json
      byebug

      response = @connection.post do |request|
        # request.headers["Content Type"] = "application/json"
        # request.headers["Authorization"] = api_key

        # request.headers["Content-Type"] = "application/json"
        request.headers = header_params
        request.body = params

        # request.headers["OpenAI-Organisation"] = org 
      end
      # response = @connection.get do |req|
      #   req.params['input'] = params[:input]
      #   req.params['cs'] = params[:cs]
      # end

    end

    def ask(opts)
  
      openai_bot_response = ""
      input_data = ""

      msg = opts[:message_body]
      
      # .downcase
      conv_id = opts[:conversation_id] || nil
      topic_id = opts[:topic_id]

      user_id = opts[:user_id]

      msg = CGI.unescapeHTML(msg.gsub(/[^a-zA-Z0-9 ]+/, "")).gsub(/[^A-Za-z0-9]/, " ").strip

      params = {input: msg, conversation_id: conv_id}
      response = make_get(params)
      byebug
      Topic.find_by(id:topic_id).conversation_id = response.id

      # reply = supplemental_info + lines
      # Open3.popen2(initiating_command) do |stdin, stdout, wait_thr|
      #   done = false
      #   line = ""
      #   lines = ""
      #   responded = false

      #   while !done
      #     line = ""
      #     begin
      #       Timeout.timeout(SiteSetting.openai_bot_text_stream_timeout) do
      #         line = stdout.gets
      #       end
      #     rescue Timeout::Error
      #       line = ""
      #     end

      #     if !line.nil? && (line.downcase.match?("\\*\\*more\\*\\*") || (line.downcase.match?("press\s") && line.match?("\sto\s"))) then
      #       stdin.putc 0xa
      #     elsif line == ""
      #       if !responded
      #         if !msg.include?('start game')
      #           stdin.puts "#{msg}\n"
      #         end
      #         responded = true
      #       elsif !saved
      #         stdin.puts save_input
      #         saved = true
      #         stdin.close
      #       end
      #     elsif stdout.eof
      #       done = true
      #       stdout.close
      #       break
      #     end

      #     if (responded || msg.include?('start game')) && !saved
      #       # skip the load
      #       if stdout.lineno > 2
      #         lines += line.lstrip
      #       end
      #     end
      #     puts line
      #   end
      # end
      # reply = supplemental_info + lines
    end
  end
end
