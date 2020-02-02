module DiscourseFrotz

  class FrotzBot < StandardError; end

  class FrotzBot
    EXEC_PATH = '~/projects/frotz/./dfrotz'.freeze
    STORY_PATH = '~/projects/frotz/stories/hhgg.z3'.freeze
    STORY_HEADER_LINES = 9
    STORY_LOAD_LINES = 6
    STORY_SAVE_LINES = 3
    SAVE_PATH = 'frotz/savegames'.freeze
    STREAM_PATH = 'frotz/streams'.freeze

    def self.strip_header_and_footer(string, show_intro)
      lines = string.split(/\n+|\r+/)

      if show_intro
        lines.delete(lines[0])
      end
  
      stripped_lines = []
  
      lines.each_with_index do |line, index|
        if line.strip[0,1] == "@"
          next
        end
  
        if (index < STORY_HEADER_LINES-1)
          if show_intro
            stripped_lines << line.gsub("\"", "'")
          end
        elsif (index < (STORY_HEADER_LINES+STORY_LOAD_LINES-1))
          #
          # Skip the load data
          #
        elsif (!show_intro && ((index + STORY_SAVE_LINES) >= lines.count+1))
          #
          # Skip the save data
          #
        elsif (!show_intro)
          stripped_lines << line.gsub("\"", "'")
        end
      end
  
      return stripped_lines.join("\n");
    end


    def self.ask(opts)
  
      msg = opts[:message_body]

      frotz_response = ""

      user_id = opts[:user_id]

      msg = CGI.unescapeHTML(msg.gsub(/[^a-zA-Z0-9 ]+/, "")).gsub(/[^A-Za-z0-9]/, " ").strip

      save_location = Pathname("#{SAVE_PATH}/#{user_id}.zsav")

      if ['save','restore','quit','exit'].include?(msg)
          return "'#{msg}' is a restricted command"
      end

      if ['reset','restart'].include?(msg)
        system("rm #{save_location}")
        return "Game reset!"
      end

      # Restore from saved path
      # \lt - Turn on line identification
      # \cm - Dont show blank lines
      # \w  - Advance the timer to now
      # Command
      # Save to save path - override Y, if file exists
      #
	    overwrite = ""
      had_save =  save_location.exist?

      if had_save
		    overwrite = "\ny"
      end

	    input_data = "restore\n#{save_location}\n\\lt\n\\cm\\w\n#{msg}\nsave\n#{save_location}#{overwrite}\n"

      input_stream = Pathname("#{STREAM_PATH}/#{user_id}.f_in")
      
      File.open(input_stream, 'w+') { |file| file.write(input_data) }

      output = `#{EXEC_PATH} -i -Z 0 #{STORY_PATH} < #{STREAM_PATH}/#{user_id}.f_in`

      lines = strip_header_and_footer(output, !had_save);

      reply = lines
    end
  end
end