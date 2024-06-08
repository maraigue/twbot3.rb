#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# ------------------------------------------------------------
# twbot3.rb - Twitter Bot Support Library in Ruby
# version 0.30
#
# (C)2024- H.Hiro(Maraigue)
# * mail: main@hhiro.net
# * web: http://maraigue.hhiro.net/twbot/
# * Twitter: http://twitter.com/h_hiro_
#
# This library is distributed under the (new) BSD license.
# See the file LICENSE.txt .
# ------------------------------------------------------------

require 'yaml'
require 'json'
require 'oauth'

# A class for X (formerly Twitter) bot framework combined with OAuth token manager.
class TwBot
  # Time to wait for opening config file if it is locked.
  WAIT_SECONDS = 2

  # @private
  # 
  # @return Provides consumer token (token to represent an app registered to Twitter) by reading the key and the secret from the config info.
  # @raise `IncompleteConfigError` if the key and the secret is not stored in the config info.
  def consumer
    if defined?(@consumer)
      return @consumer
    end

    if @config.include?('consumer_key/') && @config.include?('consumer_secret/') && @config.include?('site/') && @config.include?('authorize_path/')
      @consumer = OAuth::Consumer.new(
        @config['consumer_key/'],
        @config['consumer_secret/'],
        :site => @config['site/'],
        :authorize_path => @config['authorize_path/'],
        :debug_output => false
      )
    else
      raise IncompleteConfigError, "Consumer key and/or secret is not written in the config file. Please run \"#{$0} consumer=[KEY],[SECRET]\"."
    end
  end
  private :consumer

  # @private
  # 
  # Set up consumer token (token to represent an app registered to Twitter)
  # by specifying the key and the secret.
  # 
  # @param key Consumer key of your app.
  # @param secret Consumer secret of your app.
  # @param site Head of the URI which the app accesses. 'https://api.twitter.com' by default.
  # @param authorize_path Path of the URI in which the authentication is conducted. '/oauth/authenticate' by default.
  # @return [void]
  def set_consumer(key, secret, site = 'https://api.twitter.com', authorize_path = '/oauth/authenticate')
    @config['consumer_key/'] = key
    @config['consumer_secret/'] = secret
    @config['site/'] = site
    @config['authorize_path/'] = authorize_path
    save_config
  end
  private :set_consumer
  
  # @private
  # 
  # Saves the logs stored in the `logmsg` variable to the file, and clears them from `logmsg` variable.
  # 
  # @param log_file File name to write the log. No log will be written if it is `nil`.
  # @param logmsg Message to be written.
  # @return [void]
  def self.save_log(log_file, logmsg)
    return unless log_file

    begin
      open(log_file, "a") do |f|
        f.puts logmsg
        logmsg.replace("")
      end
    rescue Exception => e
      $stderr.puts e.twbot_errorlog_format
    end
  end
  
  # ------------------------------------------------------------
  #   Instance methods
  # ------------------------------------------------------------
  
  # Constructor.
  # 
  # == Usage(1)
  # `TwBot.new(config_file, [log_file[, list[, preserve_config[, no_post]]]])`
  # == Usage(2)
  # `TwBot.new(config_file, [log_file: ...[, list: ...[, preserve_config: ...[, no_post: ...]]]])`
  # 
  # @param [String] config_file Configuration file. Newly created if not exists.
  # @param [String] log_file File name to which the log is written. Newly created if not exists. `nil` by default (no log written).
  # @param [String] list Name of the list of messages. You may usually skip setting this; If you would like to keep multiple lists of messages and choose the list to be posted, switch the name. Empty string by default.
  # @param [Boolean] preserve_config If it is `true`, the content of the config file is not updated when you run the bot program. `false` by default.
  # @param [Boolean] no_post If it is `true`, it omits posting to Twitter (but the message will be deleted from the message list). `false` by default.
  # @return [void]
  def initialize(config_file, log_file = nil, list = '', preserve_config = false, no_post = false)
    @log_file = log_file
    
    begin
      if log_file.kind_of?(Hash)
        # If arguments are specified by a Hash
        list = log_file.fetch(:list, "")
        preserve_config = log_file.fetch(:preserve_config, false)
        no_post = log_file.fetch(:no_post, false)
        
        log_file = log_file.fetch(:log_file, nil)
      end
      
      wait = WAIT_SECONDS
      
      if config_file == nil
        raise "Configuration file is required"
      end
      @config_file = config_file
      
      @@config_file_obj ||= {}
      
      if @@config_file_obj[@config_file] && !(@@config_file_obj[@config_file].closed?)
        @@config_file_obj[@config_file].rewind
        @config = YAML.load(@@config_file_obj[@config_file].read)
      else
        if File.exist?(config_file)
          @@config_file_obj[@config_file] = open(config_file, "r+b")
          until @@config_file_obj[@config_file].flock(File::LOCK_EX | File::LOCK_NB)
            sleep 1
            wait -= 1
            raise "Configuration file is locked" if wait < 0
          end
          @config = YAML.load(@@config_file_obj[@config_file].read)
        else
          $stderr.puts "Warning: Configuration file \"#{@config_file}\" not found: newly created."
          @@config_file_obj[@config_file] = open(config_file, "a+b")
          until @@config_file_obj[@config_file].flock(File::LOCK_EX | File::LOCK_NB)
            sleep 1
            wait -= 1
            raise "Configuration file is locked" if wait < 0
          end
        end
      end
      @config = {} unless @config.kind_of?(Hash)
    
      @list = "data/#{list}"
      @preserve_config_default = preserve_config
      @preserve_config = preserve_config
      @no_post = no_post
      
      @logmsg = ""
    rescue Exception => e
      TwBot.save_log(@log_file, "<Error> "+e.twbot_errorlog_format+"\n")
      return
    end
  end

  # @private
  #
  # Displays error message of #cui_menu method to `$stderr`.
  # 
  # @return [void]
  def cui_menu_error
    $stderr.puts <<-BUF
Usage: #{$0} [modes...]

'modes' should be one of the followings:

- init:           Initializes the configuration file by an authenticated
                  user. (Browser needed)
- consumer=KEY,SECRET[,SITE][,PATH]:
                  Set the key and the secret of the Twitter app you use.
                  SITE (default: https://api.twitter.com) and PATH
                  (default: /oauth/authenticate) are set for Twitter
                  by default; you can usually omit.
- add[=USER]:     Adds an authenticated user to the configuration file.
                  (Browser needed)
- refresh[=USER]: Same as "add[=USER]", but always tries authentication
                  even if the USER is in the configuration file.
- default[=USER]: Set the default authenticated user as USER.
- run[=OPTSTR]:   Runs specified code.
                  OPTSTR is given as the variable @optstr in the code.
- load[=OPTSTR]:  Runs specified code as a Twitter bot definition; the
                  returned values (must be an array) are stored as
                  messages into the configuration file.
                  OPTSTR is given as the variable @optstr in the code.
- post[=COUNT]:   Posts messages stored by "load" mode.

Example:
  #{$0} init
  #{$0} add
  #{$0} add=h_hiro_
  #{$0} run
  #{$0} load
  #{$0} post=10
    BUF
  end
  private :cui_menu_error
  
  # Defines a bot with CUI menu.
  # With this setup,
  # - `ruby [ProgramName] init` authenticates the user account who posts messages (or other accesses to Twitter).
  # - `ruby [ProgramName] run` just runs the code given as the block. See #run.
  # - `ruby [ProgramName] load` generates the messages to be posted. See #load_messages.
  # - `ruby [ProgramName] post` posts one generated message to Twitter (and remove it from the list).
  # For other uses, see the output of #cui_menu_error (or, equivalently, run `ruby [ProgramName]`).
  # 
  # When you use TwBot instance, it is recommended to use this method (or #cui_menu or #load_messages) rather than directly calling the method (`twbot.method_name`), since the config file and log file are saved even when an error is occurred.
  # 
  # @example
  #   twbot = TwBot.new("config.yml", "error.log")
  #   twbot.cui_menu do
  #     # This `auth_http` is equivalent to `twbot.auth_http`,
  #     # since the block is run as the context of the instance `twbot`
  #     json_src = auth_http.get("/1.1/account/verify_credentials.json").body
  #     data = JSON.load(json_src)
  #     
  #     # Register the message to be posted later
  #     ["My name is #{data['screen_name']}."]
  #   end
  # 
  # @param [Proc] block The block to be run as the context of the instance (i.e., instance methods of the instance itself are available in the block.) The block must return an `Array` of `String`s if it is intended to be used with `ruby [ProgramName] load` (i.e., to define messages to be posted).
  # 
  # @return [void]
  def cui_menu(&block)
    if ARGV.empty?
      cui_menu_error
      return
    end
    
    ARGV.each do |mode|
      $stderr.puts "Running mode '#{mode}'..."
      @logmsg << "\n[cui_menu:mode=#{mode}]"
      
      action(mode, block)
    end
  end
  
  # @private
  # Parses CUI command (see #cui_menu) and acts with it.
  # 
  # @return [void]
  def action(mode, block)
    @last_run_mode = mode
    begin
      case mode
      when "init"
        dialog_authenticate_default_user
      when /\Aadd(?:=([0-9A-Z_a-z]+))?\z/
        dialog_add_user($1, false)
      when /\Arefresh(?:=([0-9A-Z_a-z]+))?\z/
        dialog_add_user($1, true)
      when /\Adefault(?:=([0-9A-Z_a-z]+))?\z/
        set_default_user($1)
      when /\Arun(?:\=(.*?))?\z/
        @optstr = $1
        run(&block)
      when /\Aload(?:\=(.*?))?\z/
        @optstr = $1
        load_messages(&block)
      when /\Apost(?:=(\d+)(?:,(\d+))?)?\z/
        # post messages from the list
        post_count = ($1 ? $1.to_i : 1)
        retries = ($2 ? $2.to_i : 0)
        post_messages(post_count, retries)
      when /\Aconsumer=/
        values = $'.split(',')
        if values.size < 2 || values.size > 4
          @logmsg << "Error: Consumer key and secret must be specified as \"consumer=[KEY],[SECRET](,[SITE](,[AUTH_PATH]))\""
          @preserve_config = true
          save_config
          return
        else
          set_consumer(*values)
        end
      else
        cui_menu_error
        @logmsg << "Error: Invalid mode"
        @preserve_config = true
        save_config
        return
      end
    rescue Exception => e
      @logmsg << "<Error>"+e.twbot_errorlog_format+"\n"
      @preserve_config = true
      save_config
    end
  end
  private :action
  
  # Runs the code under the context of the instance itself, and saves the changed config to the file.
  #
  # Consider using #cui_menu instead if you use this method only via CUI commands.
  #
  # Different from #load_messages, no message is registered as messages to be posted.
  # This method is convenient to use Twitter API but not posting messages.
  # 
  # When you use TwBot instance, it is recommended to use this method (or #cui_menu or #load_messages) rather than directly calling the method (`twbot.method_name`), since the config file and log file are saved even when an error is occurred.
  # 
  #   twbot = TwBot.new("config.yml", "error.log")
  #   twbot.run do
  #     # This `auth_http` is equivalent to `twbot.auth_http`,
  #     # since the block is run as the context of the instance `twbot`
  #     json_src = auth_http.get("/1.1/account/verify_credentials.json").body
  #     data = JSON.load(json_src)
  #     puts "My name is #{data['screen_name']}."
  #   end
  # 
  # @param [Proc] block The block to be run as the context of the instance (i.e., instance methods of the instance itself are available in the block.)
  # 
  # @return [void]
  def run(&block)
    instance_eval(&block)
    save_config
  end
  
  # Runs the code under the context of the instance itself, and store returned values to the config file as messages to be posted. Also, it saves the changed config to the file.
  #
  # Consider using #cui_menu instead if you use this method only via CUI commands.
  # 
  # When you use TwBot instance, it is recommended to use this method (or #cui_menu or #run) rather than directly calling the method (`twbot.method_name`), since the config file and log file are saved even when an error is occurred.
  #
  # @example
  #   twbot = TwBot.new("config.yml", "error.log")
  #   twbot.load_messages do
  #     # This `auth_http` is equivalent to `twbot.auth_http`,
  #     # since the block is run as the context of the instance `twbot`
  #     json_src = auth_http.get("/1.1/account/verify_credentials.json").body
  #     data = JSON.load(json_src)
  #     
  #     # Register the message to be posted later
  #     ["My name is #{data['screen_name']}."]
  #   end
  #   twbot.post_messages
  # 
  # @param [Proc] block The block to be run as the context of the instance (i.e., instance methods of the instance itself are available in the block.) The block must return an `Array` of `String`s as messages to be posted.
  # 
  # @return [void]
  def load_messages(&block)
    @config[@list] ||= []
    
    begin
      if block
        new_updates = instance_eval(&block)
      else
        new_updates = load_data
      end
      new_updates.each do |m|
        if TwBot.validate_message(m) == nil
          raise MessageFormatError, "Invalid object as a message is contained: #{m.inspect}"
        end
      end
    rescue Exception => e
      @logmsg << "<Error> "+e.twbot_errorlog_format+"\n"
      @preserve_config = true
    else
      @config[@list].concat new_updates
    end
    save_config
  end
  
  # Post messages loaded by #load_message (or equivalent command under #cui_menu) to Twitter.
  #
  # @param [Integer] post_count The number of messages stored in the message list are posted to Twitter.
  # @param [Integer] retries The number of retries when posting to Twitter failed.
  # @param [String] username The user name. By default, the default user (see #set_default_user) is used. It must be registered beforehand by the method #dialog_add_user, #dialog_authenticate_default_user or #set_default_user. (In case of using #cui_menu, it can be done by the command `ruby [ProgramName] add`, `ruby [ProgramName] init` or `ruby [ProgramName] default`, respectively.)
  # @param [String] list The list name in which the messages are stored.
  def post_messages(post_count = 1, retries = 0, username = @config["login/"], list = @list)
    while post_count > 0
      begin
        break if update_from_list(:user => username, :list => list, :duplicated => @config['duplicated/']) == nil
      rescue Exception => e
        @logmsg << "<Error in updating> #{e}\n"+e.twbot_errorlog_format+"\n"
        retries -= 1
        
        break if retries < 0
        redo
      end
      
      post_count -= 1
    end
    save_config
  end
  
  # Add a new user.
  # If 'reload' is specified true, a token will be re-retrieved.
  def dialog_add_user(username, reload = false, update_default = false)
    consumer # Check existence of consumer token

    until username
      print "User name >"
      username = STDIN.gets.chomp
      return if username.empty?
      redo unless username =~ /\A[0-9A-Z_a-z]+\z/
    end
    
    if !reload && user_registered?(username)
      puts "The user \"#{username}\" is already registered."
      return
    end
    
    auth = auth_http(:user => username, :reload => reload, :browser => true)
    if auth != nil
      puts "User \"#{username}\" is successfully registered."
      if update_default || @config["login/"] == nil
        @config["login/"] = username
        puts "Default user is set to @#{username}."
      end
    end
    save_config
  end
  
  # Sets the default user, which is applied to all TwBot methods which can specify a user.
  # If the user is not registered in the config file yet, a CUI dialog (that requires a browser) will appear.
  #
  # @param [String] username The user name to be set as default.
  #
  # @return [void]
  def set_default_user(username)
    @config["login/"] ||= nil
    if @config["login/"]
      print "Current default user is @#{@config["login/"]}."
    end
    unless username
      print "Input new default user name."
    end
    dialog_add_user(username, false, true)
  end
  
  # Sets the default user, which is applied to all TwBot methods which can specify a user.
  # If the user is not registered in the config file yet, a CUI dialog (that requires a browser) will appear.
  #
  # @param [String] username The user name to be set as default.
  #
  # @return [void]
  def dialog_authenticate_default_user
    if @config["login/"]
      # If default login user is already registered
      # (updating from twbot.rb 0.1*)
      puts <<-OUT
============================================================
Here I help you retrieve OAuth token of user "#{@config['login/']}".
Please prepare a browser to retrieve OAuth tokens.
============================================================
      OUT
        
      dialog_add_user(@config["login/"], true)
    else
      # Otherwise
      puts <<-OUT
============================================================
Here I help you register your bot account to the setting file.
Please prepare a browser to retrieve OAuth tokens.

Input the screen name of your bot account.
============================================================
      OUT
        
      dialog_add_user(nil, true)
    end
  end
  
  def save_config
    unless @preserve_config
      new_yaml = YAML.dump(@config)
      @@config_file_obj[@config_file].rewind
      @@config_file_obj[@config_file].truncate(0)
      @@config_file_obj[@config_file].print new_yaml
    end
    @preserve_config = @preserve_config_default
    
    # output log
    @logmsg = "[#{Time.now}]#{@last_run_mode ? '(mode='+@last_run_mode+')' : ''}#{@logmsg}"
    $stderr.puts @logmsg
    
    TwBot.save_log(@log_file, @logmsg)
  end
  
  # update
  def update_from_list(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      username = info
      list = @list
      duplicated = "ignore"
    when Hash
      username = info.fetch(:user, @config["login/"])
      list = info.fetch(:list, @list)
      duplicated = info.fetch(:duplicated, @config['duplicated/']).to_s
      duplicated = "ignore" if duplicated == ""
    else
      raise ArgumentError, "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
    end
    
    # post messages
    auth = auth_http(username)
    
    trial = 0
    while true
      trial += 1
      
      # prepare the message
      if @config[list].empty?
        error_message = "(error: No message remains)"
        $stderr.puts error_message
        @logmsg << error_message
        return nil
      end
      
      message = @config[list].first
      request = TwBot.validate_message(message)
      raise MessageFormatError, message.inspect if request == nil
      
      if request['text'].empty?
        # If empty string is specified
        @config[list].shift
        @logmsg << "(skipped: An empty string specified)"
        return false
      end
      request['text'].force_encoding("utf-8")
      
      # send request
      if @no_post
        result = "[]" # dummy json
      else
        post_status = auth.post("/2/tweets", JSON.dump(request), {"User-Agent" => "twbot3rb", "Content-Type" => "application/json"})
        result = post_status.body
      end
      
      # Check the result
      json_result = nil
      begin
        json_result = JSON.load(result)
      rescue 
        json_result = nil
      end
      if !json_result || (!json_result.include?("data")) || (!json_result["data"].include?("text"))
        # if failed
        if json_result && json_result.include?("detail") && json_result["detail"] == "You are not allowed to create a Tweet with duplicate content."
          # if duplicated
          error_message = "(error: The message \"#{request['text']}\" is not posted because a duplicated message is tried to be posted)"
          $stderr.puts error_message
          @logmsg << error_message
          
          case duplicated
          when "seek"
            tmp = @config[list].shift
            @config[list].push tmp
          when "discard"
            @config[list].shift
            trial -= 1
          when "cancel"
            return false
          when "ignore"
            @config[list].shift
            return false
          end
        else
          # if another reason
          raise RuntimeError, "Posting a message has failed - JSON data is:\n#{result}"
        end
      else
        # if succeeded
        
        # renew lists
        @config[list].shift
        
        # outputing / writing log
        $stderr.puts "[Updated!#{@no_post ? '(no_post)' : ''}] #{result}"
        @logmsg << "(A message has been posted)"
        return result
      end
      
      return false if trial >= @config[@list].size
    end
  end
  
  # check the user is registered in the config file
  # returns true if and only if registered with OAuth token
  def user_registered?(username)
    user_key = "users/#{username}"
    @config[user_key] && @config[user_key]["token"] && @config[user_key]["secret"]
  end
  
  # Returns access token (an instance of `OAuth::AccessToken`) for Twitter API with specified app and user.
  # 
  # HTTP access with registered OAuth token can be done like:
  #   auth_http.get(path...)
  #   auth_http.post(path...)
  #   auth_http(user).get(path...)
  # See https://www.rubydoc.info/gems/oauth/OAuth/AccessToken for details.
  # 
  # @overload auth_http(user = @config["login/"])
  #   @param user [String] The user name for which the access token is retrieved from the config file. If omitted, the default user is used.
  # @overload auth_http(user: u, reload: r, browser: b)
  #   @param u [String] The user name for which the access token is retrieved from the config file. If omitted, the default user is used.
  #   @param r [String] See below.
  #   @param b [String] If `r` is true and `b` is true, or the key for user `u` does not exist in the config file and `b` is true, then a CUI dialog will appear to retrieve the key for the user. Otherwise, the key for user `u` is retrieved from the config file.
  # 
  # @raise `ArgumentError` if the key of `user` for the token is to be retrieved from the config file but not exist.
  #
  # @return [OAuth::AccessToken] access token for Twitter API with specified app and user.
  def auth_http(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      username = info
      reload = false
      browser = false
    when Hash
      username = info.fetch(:user, @config["login/"])
      reload = info.fetch(:reload, false)
      browser = info.fetch(:browser, false)
    else
      errmsg = "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
      if info == nil
        errmsg << "\n* Perhaps you have not finished authentication. Try '#{$0} init' to register the default user."
      end
      raise ArgumentError, errmsg
    end
    
    # creates an instance of AccessToken
    user_key = "users/#{username}"
    @config[user_key] ||= {}
    
    if reload || !(user_registered?(username))
      # if token is not stored, or the library user choosed not to use stored token,
      # retrieves it with xAuth or browser
      if browser
        # with browser
        access_token = access_token_via_browser(username)
      else
        raise IncompleteConfigError, "Access token for the user @#{username} is not registered."
      end
      
      return nil if access_token == nil
      
      # Store the result to @config
      @config[user_key]["token"] = access_token.token
      @config[user_key]["secret"] = access_token.secret
      
      # return the access token
      access_token
    else
      # if token is stored, creates access token with it
      OAuth::AccessToken.new(consumer, @config[user_key]["token"], @config[user_key]["secret"])
    end
  end
  
  # ------------------------------------------------------------
  #   Class methods (Utilities)
  # ------------------------------------------------------------
  
  # Separates reply string ("@USERNAME") into "@ USERNAME"
  # to avoid unintended replies.
  # If a block is given, "@USERNAME" is separated if the result
  # of the block is true.
  def self.remove_reply(str)
    result = str.dup
    result.gsub!(/(@|＠)([0-9A-Z_a-z]+)/) do |x|
      at_mark = $1
      user_id = $2
      if block_given?
        (yield(user_id) ? "#{at_mark} #{user_id}" : x)
      else
        "#{at_mark} #{user_id}"
      end
    end
    
    result.gsub!(/#/){ |x| "# " }
    
    result
  end
  
  # Truncate the end of the string if it is longer than max_length.
  # It can be used to limit the message length to be posted to Twitter.
  # 
  # @example
  #   Twbot.truncate_to_length(5, "foobar", "...") #=> "fo..."
  # 
  # @param [Integer] max_length Maximum length of the output string. Note that, if the length of `footer` is larger than `max_length`, then `footer` itself is returned.
  # @param [String] source Source string before truncated.
  # @param [String] footer Footer string to be added.
  # @return [String] Truncated string.
  def self.truncate_to_length(max_length, source, footer = "")
    return source if source.length <= max_length
    "#{source[0, max_length - footer.length]}#{footer}"
  end
  
  # If the specified string is "true" or "false" (case insensitive),
  # returns that boolean value. Otherwise raises an exception.
  def self.parse_boolean(str)
    case str
    when /\Atrue\z/i
      true
    when /\Afalse\z/i
      false
    else
      raise ArgumentError, "Value is neither of 'true' nor 'false'"
    end
  end
  
  # Converts values from user-defined "load_post" method
  # into HTTP request.
  # Returns nil if the value is invalid.
  def self.validate_message(obj)
    case obj
    when String
      {'text' => obj}
    when Array
      return nil if obj.size != 2
      {'text' => obj[0], 'reply' => {'in_reply_to_tweet_id' => obj[1].to_s}}
    when Hash
      obj
    else
      nil
    end
  end
  
  # Get OAuth token (via browser)
  def access_token_via_browser(username)
    # reference: https://shibason.hatenadiary.org/entry/20090802/1249204953 (in Japanese)
    
    request_token = consumer.get_request_token
    
    puts <<-OUT
============================================================
To retrieve OAuth token of user "#{username}":
(1) Log in Twitter with a browser for user "#{username}".
(2) Access the URL below with same browser:
    #{request_token.authorize_url}
(3) Check the application name is the one you registered,
    and if so, click "Allow" link in the browser.
(4) Input the shown number (PIN number).
    To cancel, input nothing and press enter key.
============================================================
    OUT
    
    pin_number = nil
    begin
      print "PIN number > "
      pin_number = STDIN.gets.chomp
    end until pin_number && pin_number =~ /\A\d*\z/
    
    return nil if pin_number == ""

    token = request_token.token
    token_secret = request_token.secret
    hash = { :oauth_token => token, :oauth_token_secret => token_secret }
    request_token  = OAuth::RequestToken.from_hash(consumer, hash)
  
    # Get access token
    access_token = request_token.get_access_token(:oauth_verifier => pin_number)
  end

  # ------------------------------------------------------------
  #   Exceptions
  # ------------------------------------------------------------
  
  # Raised when a lack of information is found in config file.
  class IncompleteConfigError < RuntimeError
  end
  
  # Raised when the elements of array returned from load_data() is invalid.
  class MessageFormatError < RuntimeError
  end
end

# @private
# Extension of `Exception` class for formatting exception message for twbot3.rb
class Exception
  # @private
  # Formats exception message for twbot3.rb.
  def twbot_errorlog_format
    "#{self.class}: #{self}\n"+self.backtrace.map{ |x| "\t#{x}" }.join("\n")
  end
end
