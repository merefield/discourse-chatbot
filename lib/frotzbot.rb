module DiscourseFrotz

  class FrotzBot < StandardError; end

  class FrotzBot

    ## ANSIname => ANSIcode LUT
    ANSINAME2CODE= {  "reset"     => "\e[0m",    "bold"       => "\e[1m",
      "underline" => "\e[4m",    "blink"      => "\e[5m",
      "reverse"   => "\e[7m",    "invisible"  => "\e[8m",
      "black"     => "\e[0;30m", "darkgrey"   => "\e[1;30m",
      "red"       => "\e[0;31m", "lightred"   => "\e[1;31m",
      "green"     => "\e[0;32m", "lightgreen" => "\e[1;32m",
      "brown"     => "\e[0;33m", "yellow"     => "\e[1;33m",
      "blue"      => "\e[0;34m", "lightblue"  => "\e[1;34m",
      "purple"    => "\e[0;35m", "magenta"    => "\e[1;35m",
      "cyan"      => "\e[1;36m", "lightcyan"  => "\e[1;36m",
      "grey"      => "\e[0;37m", "white"      => "\e[1;37m",
      "bgblack"   => "\e[40m",   "bgred"      => "\e[41m",
      "bggreen"   => "\e[42m",   "bgyellow"   => "\e[43m",
      "bgblue"    => "\e[44m",   "bgmagenta"  => "\e[45m",
      "bgcyan"    => "\e[46m",   "bgwhite"    => "\e[47m"
    }

    ## BBColor => ANSIname LUT
    BBCOLOR2ANSI  = { "skyblue"   => "blue",     "royalblue" => "blue",
        "blue"      => "blue",     "darkblue"  => "blue",
        "orange"    => "red",      "orangered" => "red",
        "crimson"   => "red",      "red"       => "lightred",
        "firebrick" => "red",      "darkred"   => "red",
        "green"     => "green",    "limegreen" => "green",
        "seagreen"  => "green",    "darkgreen" => "green",
        "deeppink"  => "magenta",  "tomato"    => "red",
        "coral"     => "cyan",     "purple"    => "purple",
        "indigo"    => "blue",     "burlywood" => "red",
        "sandybrown"=> "red",      "sierra"    => "sierra",
        "chocolate" => "brown",    "teal"      => "teal",
        "silver"    => "white",
        "black"     => "black",    "yellow"    => "yellow",
        "magenta"   => "magenta",  "cyan"      => "cyan",
        "white"     => "white"
      }

    ## ANSInames => BBCode LUT
    ANSINAME2BBCODE = { "bold" => "B", "underline" => "U", "reverse" => "I",

          "red"    => "color=red",      "blue"   => "color=blue",
          "green"  => "color=green",    "cyan"   => "color=cyan",
          "magenta"=> "color=deeppink", "purple" => "color=purple",
          "black"  => "color=black",    "white"  => "color=white",
          "yellow" => "color=yellow",   "brown"  => "color=chocolate",
          "bgblack"   => "bgcolor=black",   "bgred"      => "bgcolor=red",
          "bggreen"   => "bgcolor=green",   "bgyellow"   => "bgcolor=yellow",
          "bgblue"    => "bgcolor=blue",   "bgmagenta"  => "bgcolor=magenta",
          "bgcyan"    => "bgcolor=cyan",   "bgwhite"    => "bgcolor=white"
        }

    # ---------------------------

    # Returns the string with all ansi escape sequences converted to BBCodes
    def self.ansi_to_bbcode(string)
      return "" if string.nil? || string.to_s.strip.empty?
      result = ""
      tagstack = []

      ## Iterate over input lines
      string.split("\n").each do |line|
        ## Iterate over found ansi sequences
        line.scan(/\e\[[0-9;]+m/).each do |seq|
          ansiname = ANSINAME2CODE.invert["#{seq}"]

        ## Pop last tag and form closing tag
          if ansiname == "reset"
            lasttag = tagstack.pop
            bbname = "/" + String.new( lasttag.split("=")[0] )

          ## Get corresponding BBCode tag + Push to stack
          else
            bbname   = ANSINAME2BBCODE[ansiname]
            tagstack.push(bbname)
          end

          ## Replace ansi sequence by BBCode tag
          replace = sprintf("[%s]", bbname)
          line.sub!(seq, replace)
        end

        ## Append converted line
        result << sprintf("%s\n", line)
      end

      ## Some tags are unclosed
      while !tagstack.empty?
        result << sprintf("[/%s]", String.new(tagstack.pop.split("=")[0])  )
      end

      return result
    end

    def self.strip_header_and_footer(string)

      lines = string.split(/\n+|\r+/)

      # Always ignore the first two lines which are Frotz housekeeping
      lines.delete_at(0)
      lines.delete_at(0)

      stripped_lines = []

      lines.each_with_index do |line, index|

        if  ["@", ">"].include? line.strip[0,1]
          next
        end

        ## Pre-process the ASCII codes

        line.gsub!("\e[0K","")  #suppress clear formats
        line.gsub!(/\e\[3.m/) {|substring| substring[0..1] + "0;" + substring [2..4]} #convert 8bit ASCII colours to ANSI
        line.gsub!("\e[27m","") #suppress invert
        line.gsub!("\e[7m","")  #suppress reverse
        line.gsub!("\e[0;37m","\e[1;37m")  #tweak colours
        line.gsub!("\e[0;36m","\e[1;36m")  #tweak colours

        unless line.squish == "Ok." || line.squish == ""
          stripped_lines << ansi_to_bbcode(line.gsub("\"", "'"))
        end
      end

      return stripped_lines.join("\n")
    end

    def self.list_games

      game_settings = SiteSetting.frotz_stories.split('|')
      games_list = ""
      
      game_settings.each_with_index do |line, index|
        game = line.split(',')
        games_list +="#{index+1}. #{game[0]}\n"
      end

      games_list
    end

    def self.ask(opts)
  
      frotz_response = ""
      save_location = ""
      new_save_location = ""
      game_file = ""
      game_file_prefix = ""
      game_title = ""
      supplemental_info = ""
      game_number = 1
      overwrite = ""
      input_data = ""

      msg = opts[:message_body].downcase

      user_id = opts[:user_id]

      available_games = list_games

      msg = CGI.unescapeHTML(msg.gsub(/[^a-zA-Z0-9 ]+/, "")).gsub(/[^A-Za-z0-9]/, " ").strip

      current_users_save_files = `ls -t #{SiteSetting.frotz_saves_directory}/*_#{user_id}.zsav`
      
      executable_check = `ls -t #{SiteSetting.frotz_dumb_executable_directory}/dfrotz`

      if executable_check.blank?
        return I18n.t('frotz.errors.noexecutable')
      end 

      save_location = Pathname(current_users_save_files.split("\n").first.blank? ? "" : current_users_save_files.split("\n").first)
      
      if save_location
        first_filename = save_location.basename.to_s
        if first_filename.include?('_')
          current_game_file_prefix = first_filename.split('_')[0]

          available_games = SiteSetting.frotz_stories.split('|')

          available_games.each_with_index do |line, index|
              game = line.split(',')
              story_file = game[1]

              if story_file.include?(current_game_file_prefix)
                game_number = index + 1
                game_file = story_file
              end
          end
        end
      end
     
      if ['save','restore','quit','exit'].include?(msg)
          return "'#{msg}' #{I18n.t('frotz.errors.restricted')}"
      end

      if ['reset game'].include?(msg)
        if current_users_save_files.length
          `rm #{save_location}`
          supplemental_info = "**Game Reset:**\n\n"
          msg = "start game #{game_number}"
        else
          return I18n.t('frotz.errors.nosavefile')
        end
      end

      if msg.include?('list games')
        return list_games
      end

      if msg.include?('continue game') || msg.include?('start game')
        if !msg[/\d+/].nil?
          game_index = msg[/\d+/].to_i - 1

          available_games = SiteSetting.frotz_stories.split('|')

          if !game_index.between?(0, available_games.count - 1)
            return I18n.t('frotz.errors.invalidgamenumber')
          end

          available_games.each_with_index do |line, index|
          
            if index == game_index
              game = line.split(',')
              game_title = game[0]
              game_file = game[1]
              story_header_lines = game[2].to_i
              story_load_lines = game[3].to_i
              story_save_lines = game[4].to_i
              supplemental_info = "**#{I18n.t('frotz.responses.starting')} #{game_title}:**\n\n"
              save_location = ""
              new_save_location = Pathname("#{SiteSetting.frotz_saves_directory}/#{game_file.split('.')[0]}_#{user_id}.zsav")
            end
          end
          
          if msg.include?('continue game')

            found_save = false
            
            available_saves = current_users_save_files.split("\n")

            available_saves.each_with_index do |save, index|
            
              if Pathname(save).basename.to_s.include?(game_file.split(".")[0])
                save_location = Pathname(save)
                new_save_location = Pathname(save)
                found_save = true
              end
            end

            if !found_save
              save_location = ""
            end
            supplemental_info = "**#{I18n.t('frotz.responses.continuing')} #{game_title}:**\n\n"
            msg = "look"
          end
        else
          return I18n.t('frotz.errors.gamenotspecified')
        end
      end

      if game_file.blank?
        return I18n.t('frotz.errors.gamenotspecified')
      end

      if save_location.blank?
        story_load_lines = 0
      else
        if new_save_location.blank?
          new_save_location = save_location
        end
      end

      # Restore from saved path
      # \lt - Turn on line identification
      # \cm - Dont show blank lines
      # \w  - Advance the timer to now
      # Command
      # Save to save path - override Y, if file exists

      overwrite = "\ny"

      story_path_check = `ls -t #{SiteSetting.frotz_story_files_directory}/#{game_file}`

      if story_path_check.blank?
        return I18n.t('frotz.errors.nostoryfile')
      end 

      story_path = Pathname("#{SiteSetting.frotz_story_files_directory}/#{game_file}")

      input_data += "#{msg}\nsave\n#{new_save_location}#{overwrite}\n\cD"

      if save_location.blank?
        output, s = Open3.capture2("#{SiteSetting.frotz_dumb_executable_directory}/./dfrotz -f ansi -i -Z 0 #{story_path}", :stdin_data=>input_data, :binmode=>true )
      else
        output, s = Open3.capture2("#{SiteSetting.frotz_dumb_executable_directory}/./dfrotz -L #{save_location} -f ansi -i -Z 0 #{story_path}", :stdin_data=>input_data, :binmode=>true )
      end

      puts "BEFORE strip:\n"+output
      lines = strip_header_and_footer(output)
      puts "AFTER strip:\n"+lines

      reply = supplemental_info + lines
    end
  end
end