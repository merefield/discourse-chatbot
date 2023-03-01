# discourse-chatbot

A plugin that uses a cloud-based chatbot to provide an response useful interactive ai experience.

Is extensible but currently only supports interaction with Open AI Large Language models such as GPT3.  This may change in the future.  Please contact me if you wish to add additional bot types.  PR welcome.

Upon addition to a Discourse, the plugin currently sets up a AI bot user with the following attributes

* Name: 'AIBot'
* User Id: -4
* Group Name: "ai_bot_group"
* Group Full Name: "AI Bots"

You can edit the name as you wish but make it easy to mention.

*There is some minor setup required before you can use the bot*.

You must get a token from https://openai.com in order to use the current bot.  A default language model is set (one of the most sophisticated), but you can try a cheaper alternative, the list is here: <a>https://platform.openai.com/docs/models/overview</a>'

There is a quota system.  In order to interact with the bot you must belong to a group that has been added to one of the three levels of trusted sets of groups, low, medium & high trust group sets.  You can modify each of the number of allowed interactions per week per trusted group sets in the corresponding settings.

You can prompt the bot to respond by replying to it, or @ mentioning it.  You can set how far the bot looks behind to get context for a response.  The bigger the value the more costly will be each call.

## TODO

* Add front and back-end tests