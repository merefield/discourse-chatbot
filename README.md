# discourse-chatbot

# What is it?

* The original Discourse AI Chatbot!
* Converse with the bot in any Post or Chat Channel, one to one or with others!
* Customise the character of your bot to suit your forum!
  * want it to sound like William Shakespeare, or Winston Churchill? can do!
* The new "RAG mode" can now:
  * Search your whole* forum for answers so the bot can be an expert on the subject of your forum.
    * not just be aware of the information on the current Topic or Channel.
  * Search Wikipedia
  * Search current news*
  * Search Google*
  * Return current End Of Day market data for stocks.*
  * Do "complex" maths accurately (with no made up or "hallucinated" answers!)
* EXPERIMENTAL Vision support - the bot can see your pictures and answer questions on them! (turn `chatbot_support_vision` ON)
* Uses cutting edge Open AI API and functions capability of their excellent, industry leading Large Language Models.
* Includes a special quota system to manage access to the bot: more trusted and/or paying members can have greater access to the bot!
* Also supports Azure and proxy server connections
  * Use third party proxy processes to translate the calls to support alternative LLMs like Gemini e.g. [this one](https://github.com/PublicAffairs/openai-gemini)

<sup>*sign-up for external (not affiliated) API services required. Links in settings.


There are two modes:

- RAG mode is very smart and knows facts posted on your forum.

- Basic bot mode can sometimes make mistakes, but is cheaper to run because it makes fewer calls to the Large Language Model:

### :biohazard: **Bot access and privacy :biohazard:

This bot can be used in public spaces on your forum.  To make the bot especially useful there is RAG mode (one setting per bot trust level).  This is not set by default.

In RAG mode the bot is, by default, goverened by setting `chatbot embeddings strategy` (default `benchmark_user`) privy to all content a Trust Level 1 user would see.  Thus, if interacted with in a public facing Topic, there is a possibility the bot could  "leak" information if you tend to gate content at the Trust Level 0 or 1 level via Category permissions.  This level was chosen because through experience most sites usually do not gate sensitive content at low trust levels but it depends on your specific needs.

For this mode, make sure you have at least one user with Trust Level 1 and no additional group membership beyond the automated groups.  (bear in mind the bot will then know everything a TL1 level user would know and can share it).  You can choose to lower `chatbot embeddings benchmark user trust level` if you have a Trust Level 0 user with no additional group membership beyond automated groups.

Alternatively:

* Switch `chatbot embeddings strategy` to `category` and populate `chatbot embeddings categories` with Categories you wish the bot to know about.  (Be aware that if you add any private Categories, it should know about those and anything the bot says in public, anywhere might leak to less privileged users so just be a bit careful on what you add).
* only use the bot in `basic` mode (but the bot then won't see any posts)
* mitigate with moderation

You can see that this setup is a compromise.  In order to make the bot useful it needs to be knowledgeable about the content on your site.  Currently it is not possible for the bot to selectively read members only content and share that only with members which some admins might find limiting but there is no way to easily solve the that whilst the bot is able to talk in public. Contact me if you have special needs and would like to sponsor some work in this space. Bot permissioning with semantic search is a non-trivial problem.  The system is currently optimised for speed.  NB Private Messages are never read by the bot.

# FYI's

* Open AI API response can be slow at times on more advanced models due to high demand.  However Chatbot supports GPT 3.5 too which is fast and responsive and perfectly capable.
* Is extensible and supporting other cloud bots is intended (hence the generic name for the plugin), but currently 'only' supports interaction with Open AI Large Language Models (LLM) such as GPT-4 natively. Please contact me if you wish to add additional bot types or want to support me to add more. PR welcome.  Can already use proxy servers to access other services without code changes though!
* Is extensible to support the searching of other content beyond just the current set provided.

# Setup

## Creating the Embeddings

If you wish Chatbot to know about the content on your site, turn this setting ON:

`chatbot_embeddings_enabled`

Only necessary if you want to use the RAG type bot and ensure it is aware of the content on your forum, not just the current Topic.

Initially, we need to create the embeddings for all in-scope posts, so the bot can find forum information.  This now happens in the background once this setting is enabled and you do not need to do anything.

This seeding job can take a period of days for very big sites.

### Embeddings Scope

This is determined by several settings:

* `chatbot_embeddings_strategy` which can be either "benchmark_user" or "category"
* `chatbot_embeddings_benchmark_user_trust_level` sets the relevant trust level for the former
* `chatbot_embeddings_categories` if `category` strategy is set, gives the bot access to consider all posts in specified Category.

If you change these settings, over time, the population of Embeddings will morph.

### To speed population up

Enter the container:

`./launcher enter app`

and run the following rake command:

`rake chatbot:refresh_embeddings[1]`

which at present will run twice due to unknown reason (sorry! feel free to PR) but the `[1]` ensures the second time it will only add missing embeddings (ie none immediately after first run) so is somewhat moot.

In the unlikely event you get rate limited by OpenAI (unlikely!) you can complete the embeddings by doing this:

`rake chatbot:refresh_embeddings[1,1]`

which will fill in the missing ones (so nothing lost from the error) but will continue more cautiously putting a 1 second delay between each call to Open AI.

Compared to bot interactions, embeddings are not expensive to create, but do watch your usage on your Open AI dashboard in any case.

NB Embeddings are only created for Posts and only those Posts for which a Trust Level One user would have access.  This seemed like a reasonable compromise.  It will not create embeddings for posts from Trust Level 2+ only accessible content.

### Useful Data Explorer query to monitor embeddings population

@37Rb writes: "Here’s a SQL query I’m using with the [Data Explorer](https://meta.discourse.org/t/discourse-data-explorer/32566) plugin to monitor & verify embeddings… in case it helps anyone else."

```
SELECT e.id, e.post_id AS post, p.topic_id AS topic, p.post_number,
       p.topic_id, e.created_at, e.updated_at, p.deleted_at AS post_deleted
FROM chatbot_post_embeddings e LEFT JOIN posts p ON e.post_id = p.id
```

### Error when you are trying to get an embedding for too many characters.

You might get an error like this:

```
OpenAI HTTP Error (spotted in ruby-openai 6.3.1): {"error"=>{"message"=>"This model's maximum context length is 8192 tokens, however you requested 8528 tokens (8528 in your prompt; 0 for the completion). Please reduce your prompt; or completion length.", "type"=>"invalid_request_error", "param"=>nil, "code"=>nil}}
```
This is how you resolve it ...

As per your error message, the embedding model has a limit of:

`8192 tokens`

`however you requested 8528`

You need to drop the current value of this setting:

`chatbot_open_ai_embeddings_char_limit:`

by about 4 x the diff and see if it works (a token is *roughly* 4 characters).

So, in this example, 4 x (8528 - 8192) = 1344

So drop `chatbot_open_ai_embeddings_char_limit` current value by 1500 to be safe. However, the default value was set according to a lot of testing for English Posts, but for other languages it may need lowering.

This will then cut off more text and request tokens and hopefully the embedding will go through. If not you will need to confirm the difference and reduce it further accordingly. Eventually it will be low enough so you don’t need to look at it again.

### How To Switch Embeddings model

You don't need to do anything but change the setting: the background job will take care of things, if gradually.

If you really want to speed the process up, do:

* Change the setting `chatbot_open_ai_embeddings_model` to your new preferred model
* It's best to first delete all your current embeddings:
  * go into the container `./launcher enter app`
  * enter the rails console `rails c`
  * run `::DiscourseChatbot::PostEmbedding.delete_all`
  * `exit` (to return to root within container)
* run `rake chatbot:refresh_embeddings[1]`
* if for any Open AI side reason that fails part way through, run it again until you get to 100%
* the new model is known to be more accurate, so you might have to drop `chatbot_forum_search_function_similarity_threshold` or you might get no results :).  I dropped my default value from `0.8` to `0.6`, but your mileage may vary.

## Bot Type

Take a moment to read through the entire set of Plugin settings.  The `chatbot bot type` setting is key, and there is one for each chatbot "Trust Level":

![image|642x125](upload://cydPijPWWd5FHp8pagYtfofqRU2.png)

RAG mode is superior but will make more calls to the API, potentially increasing cost.  That said, the reduction in its propensity to ultimately output 'hallucinations' may facilitate you being able to drop down from GPT-4 to GPT-3.5 and you may end up spending less despite the significant increase in usefulness and reliability of the output.  GPT 3.5 is also a better fit for the Agent type based on response times.  A potential win-win! Experiment!

For Chatbot to work in Chat you must have Chat enabled.

## Bot's speed of response

This is governed mostly by a setting: `‎chatbot_reply_job_time_delay‎` over which you have discretion.

The intention of having this setting is to:

* protect you from reaching rate limits of Open AI
* protect your site from users that would like to spam the bot and cost you money.

It is now default '1' second and can now be reduced to zero :racing_car: , but be aware of the above risks.

Setting this zero and the bot, even in 'agent' mode, becomes a lot more 'snappy'.

Obviously this can be a bit artificial and no real person would actually type that fast ... but set it to your taste and wallet size.

NB I cannot directly control the speed of response of Open AI's API - and the general rule is the more sophisticated the model you set the slower this response will usually be.  So GPT 3.5 is much faster that GPT 4 ... although this may change with the newer GPT 4 Turbo model.

For Chatbot to work in Chat you must have Chat enabled.

## OpenAI

You must get a [token](https://platform.openai.com/account/api-keys) from [https://platform.openai.com/](https://platform.openai.com/) in order to use the current bot. A default language model is set (one of the most sophisticated), but you can try a cheaper alternative, [the list is here](https://platform.openai.com/docs/models/overview)

There is an automated part of the setup: upon addition to a Discourse, the plugin currently sets up a AI bot user with the following attributes

* Name: 'Chatbot'
* User Id: -4
* Bio: "Hi, I’m not a real person. I’m a bot that can discuss things with you. Don't take me too seriously.  Sometimes, I'm even right about stuff!"
* Group Name: "ai_bot_group"
* Group Full Name: "AI Bots"

You can edit the name, avatar and bio (see locale string in admin -> customize -> text) as you wish but make it easy to mention.

## It's not free, so there's a quota system, and you have to set this up

Initially **no-one** will have access to the bot, not even staff.

Calling the Open AI API is not free after an initial free allocation has expired! So, I've implemented a quota system to keep this under control, keep costs down and prevent abuse.  The cost is not crazy with these small interactions, but it may add up if it gets popular. You can read more about OpenAI pricing [on their pricing page](https://openai.com/pricing).

In order to interact with the bot you must belong to a group that has been added to one of the three levels of trusted sets of groups, low, medium & high trust group sets. You can modify each of the number of allowed interactions per week per trusted group sets in the corresponding settings.

You must populate the groups too.  That configuration is entirely up to you.  They start out blank so initially **no-one** will have access to the bot.  There are corresponding quotas in three additional settings.

Note the user gets the quota based on the highest trusted group they are a member of.

## "Prompt Engineering"

There are several locale text "settings" that influence what the bot receives and how the bot responds.

The most important one you should consider changing is the bot's `system` prompt.  This is sent every time you speak to the bot.

For the basic bot, you can try a system prompt like:

’You are an extreme Formula One fan, you love everything to do with motorsport and its high octane levels of excitement’ instead of the default.

(For the agent bot you must keep everything after "You are a helpful assistant." or you may break the agent behaviour.  Reset it if you run into problems.  Again experiment!)

Try one that is most appropriate for the subject matter of your forum.  Be creative!

Changing these locale strings can make the bot behave very differently but cannot be amended on the fly.  I would recommend changing only the system prompt as the others play an important role in agent behaviour or providing information on who said what to the bot.

NB In Topics, the first Post and Topic Title are sent in addition to the window of Posts (determined by the lookback setting) to give the bot more context.

You can edit these strings in Admin -> Customize -> Text under `chatbot.prompt.`

https://github.com/merefield/discourse-chatbot/blob/262a0a419fa261d7771a23fe07361cdfa78196eb/config/locales/server.en.yml#L45

# Supports both Posts & Chat Messages!

The bot supports Chat Messages and Topic Posts, including Private Messages (if configured).

You can prompt the bot to respond by replying to it, or @ mentioning it. You can set how far the bot looks behind to get context for a response. The bigger the value the more costly will be each call.

There's a floating quick chat button that connects you immediately to the bot. This can be disabled in settings. You can choose whether to load the bot into a 1 to 1 chat or a Personal Message.

Now you can choose your preferred icon (default :robot: ) or if setting left blank, will pick up the bot user's avatar! :sunglasses: 

And remember, you can also customise the text that appears when it is expanded by editing the locale text using Admin -> Customize -> Text `chatbot.`

# Uninstalling the plugin

The only step necessary to remove it is to delete the clone statement from your `app.yml`.

**Disclaimer**: I'm *not* responsible for what the bot responds with. Consider the plugin to be at Beta stage and things could go wrong. It will improve with feedback.  But not necessarily the bots response :rofl:  Please understand the pro's and con's of a LLM and what they are and aren't capable of and their limitations.  They are very good at creating convincing text but can often be factually wrong.

**Important Privacy Note**: whatever you write on your forum may get forwarded to Open AI as part of the bots scan of the last few posts once it is prompted to reply (obviously this is restricted to the current Topic or Chat Channel).  Whilst it almost certainly won't be incorporated into their pre-trained models, they will use the data in their analytics and logging.  **Be sure to add this fact into your forum's TOS & privacy statements**.  Related links:  https://openai.com/policies/terms-of-use, https://openai.com/policies/privacy-policy, https://platform.openai.com/docs/data-usage-policies

**Copyright**: Open AI made a statement about Copyright here: https://help.openai.com/en/articles/5008634-will-openai-claim-copyright-over-what-outputs-i-generate-with-the-api
