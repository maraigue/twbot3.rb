# twbot3.rb

**twbot3.rb** is an X (formerly Twitter) bot framework combined with OAuth token manager.

This is a derivative work of [twbot2.rb](https://github.com/maraigue/twbot2.rb); twbot3.rb uses API v2 rather than API v1.

**Notice: "Twitter" was renamed to "X", but in this document it is called "Twitter" for higher identifiability.**

# 日本語での説明 (in Japanese)

http://maraigue.hhiro.net/twbot/ または https://github.com/maraigue/twbot3.rb/wiki をご覧ください。

# Changes from twbot2.rb

-   In twbot2.rb, it posts messages by API version 1. However, since API version 1 has been ended the service (except for some cases), twbot2.rb cannot work now. twbot3.rb uses API version 2 which is now in service.
-   In twbot2.rb, it includes the key and the secret of app "twbot2.rb", that is, the key and the secret are shared by all users (unless you rewrite). However, since API limitations are altered, it is now difficult to share. In twbot3.rb a function to register the key and the secret of your app.
    -   Therefore, you need to register your app in [Twitter developer portal](https://developer.twitter.com/en/portal/dashboard) at first, and then to register the key and the secret in twbot3.rb.
-   Since most API functions except posting messages cannot be available with [free plan](https://developer.twitter.com/en/docs/twitter-api/getting-started/about-twitter-api), other functions than posting (e.g., retrieve followers) implemented in twbot2.rb has been deleted.

# Example

We have only to define messages posted by the bot as the following format:

    $ cat twbot3-sample-post.rb
    
    #!/usr/bin/env ruby
    # -*- coding: utf-8 -*-
    
    require "./twbot3"
    TwBot.create("config-post.yml", "error-post.log").cui_menu do
      ['Test message!']
    end

For instructions to prepare environment, please see `INSTRUCTIONS.md`.

# Copyrights

The original author, H.Hiro(Maraigue), distributes the library under "new BSD License". You may re-distribute a modified library as long as the original version's license text is included (details are shown in LICENSE.txt).

# Contact

Original author: H.Hiro(Maraigue) (e-mail: main at hhiro.net, website: http://hhiro.net/)

To request new features and/or bug fixes, contact the e-mail address or send a pull request via GitHub (https://github.com/maraigue/twbot3.rb/).
