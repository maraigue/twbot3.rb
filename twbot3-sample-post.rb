#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "./twbot3"

# Example: post a (fixed) message
# 
# To run the example,
# - First try "ruby twbot3-sample-post.rb run". The content in the block
#   (extracting authenticated user) will be conducted and probably
#   results in the message you are not authenticated.
# - Then run "ruby twbot3-sample-post.rb consumer=[KEY],[SECRET]", where
#   [KEY],[SECRET] are the one in your app registered in Twitter developer
#   portal https://developer.twitter.com/en/portal/dashboard .
# - Then run "ruby twbot3-sample-post.rb init". A dialog will appear to
#   authenticate you. (You need a browser)
# - Finally run "ruby twbot3-sample-post.rb run" again. A post will be
#   made from the authenticated account.

TwBot.new("config-post.yml", "error-post.log").cui_menu do
  # Twbot#cui_menu should return a list of posts.
  # So, in order to post once, you should return an array containing
  # one text.
  ['Test message!']
end
