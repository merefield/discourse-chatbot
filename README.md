# discourse-chatbot

A plugin that uses a cloud-based chatbot to provide a useful interactive ai experience.

Is extensible and supporting other cloud bots is intended (hence the generic name for the plugin), but currently 'only' supports interaction with Open AI Large Language models such as GPT3.  This may change in the future.  Please contact me if you wish to add additional bot types or want to support me to add more.  PR welcome.

Upon addition to a Discourse, the plugin currently sets up a AI bot user with the following attributes

* Name: 'AIBot'
* User Id: -4
* Group Name: "ai_bot_group"
* Group Full Name: "AI Bots"

You can edit the name as you wish but make it easy to mention.

### Setup

*There is some minor setup required before you can use the bot*: take a moment to read through the entire set of Plugin settings.

You must get a token from https://openai.com in order to use the current bot.  A default language model is set (one of the most sophisticated), but you can try a cheaper alternative, the list is here: <a>https://platform.openai.com/docs/models/overview</a>'

There is a quota system.  In order to interact with the bot you must belong to a group that has been added to one of the three levels of trusted sets of groups, low, medium & high trust group sets.  You can modify each of the number of allowed interactions per week per trusted group sets in the corresponding settings.

The bot supports Chat Messages and Topic Posts, including Private Messages (if configured).

You can prompt the bot to respond by replying to it, or @ mentioning it.  You can set how far the bot looks behind to get context for a response.  The bigger the value the more costly will be each call.

There's a floating quick chat button that connects you immediately to the bot.  Its styling is a little experimental and it may clash on some pages.  This can be disabled in settings.

Disclaimer: I'm not responsible for what the bot responds with.  Consider the plugin to be at Beta stage and things could go wrong.  It will improve with feedback.

### TODO

* Add front and back-end tests
