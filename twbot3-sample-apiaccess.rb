#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "./twbot3"

# Example: show the name of the authenticated user
# 
# To run the example,
# - First try "ruby twbot3-sample-apiaccess.rb run". The content in the block
#   (extracting authenticated user) will be conducted and probably
#   results in the message you are not authenticated.
# - Then run "ruby twbot3-sample-apiaccess.rb consumer=[KEY],[SECRET]", where
#   [KEY],[SECRET] are the one in your app registered in Twitter developer
#   portal https://developer.twitter.com/en/portal/dashboard .
# - Then run "ruby twbot3-sample-apiaccess.rb init". A dialog will appear to
#   authenticate you. (You need a browser)
# - Finally run "ruby twbot3-sample-apiaccess.rb run" again. A message you have
#   been authenticated will be shown.

TwBot.new("config-apiaccess.yml", "error-apiaccess.log").cui_menu do
  json_src = auth_http.get("/1.1/account/verify_credentials.json").body
  data = JSON.load(json_src)
  puts "You are authenticated as @#{data["screen_name"]}."

  # Since Twbot#cui_menu should return a list of posts,
  # it should return an empty array if no post should be made.
  []
end
