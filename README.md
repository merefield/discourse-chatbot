# discourse-chatbot

# What is it?

* The original Discourse AI Chatbot!
* Converse with the bot in any Post or Chat Channel, one to one or with others!
* Customise the character of your bot to suit your forum!
  * want it to sound like William Shakespeare, or Winston Churchill? can do!
* The new "Agent Mode" can now:
  * Search your whole* forum for answers so the bot can be an expert on the subject of your forum.
    * not just be aware of the information on the current Topic or Channel.
  * Search Wikipedia
  * Search current news*
  * Search Google*
  * Return current End Of Day market data for stocks.*
  * Do "complex" maths accurately (with no made up or "hallucinated" answers!)
* Uses cutting edge Open AI API and functions capability of their excellent, industry leading Large Language Models.
* Includes a special quota system to manage access to the bot: more trusted and/or paying members can have greater access to the bot!

<sup>*sign-up for external (not affiliated) API services required. Links in settings.


There are two modes:

- Agent mode is very smart and knows facts posted on your forum.

- Normal bot mode can sometimes make mistakes, but is cheaper to run because it makes fewer calls to the Large Language Model:

### :biohazard: **Bot access and privacy :biohazard:

This bot can be used in public spaces on your forum.  To make the bot especially useful there is the new (currently experimental) Agent mode.  This is not set by default.

In this mode the bot is, by default, privy to all content a Trust Level 1 user would see.  Thus, if interacted with in a public facing Topic, there is a possibility the bot could  "leak" information if you tend to gate content at the Trust Level 0 or 1 level via Category permissions.  This level was chosen because through experience most sites usually do not gate sensitive content at low trust levels but it depends on your specific needs. This can be eliminated by only using the bot in normal mode or mitigated with moderation of course.

You can see that this setup is a compromise.  In order to make the bot useful it needs to be knowledgeable about the content on your site.  Currently it is not possible for the bot to selectively read members only content and share that only with members which some admins might find limiting but there is no way to easily solve the that whilst the bot is able to talk in public. Contact me if you have special needs and would like to sponsor some work in this space. Bot permissioning with semantic search is a non-trivial problem.  The system is currently optimised for speed.  NB Private Messages are never read by the bot.

# FYI's

* May not work on mulit-site installs (not explicitly tested), but PR welcome to improve support :+1: 
* Open AI API response can be slow at times on more advanced models due to high demand.  However Chatbot supports GPT 3.5 too which is fast and responsive and perfectly capable.
* Is extensible and supporting other cloud bots is intended (hence the generic name for the plugin), but currently 'only' supports interaction with Open AI Large Language Models (LLM) such as "ChatGPT". This may change in the future. Please contact me if you wish to add additional bot types or want to support me to add more. PR welcome.
* Is extensible to support the searching of other content beyond just the current set provided.

# Setup

## Intro

Be patient, it's worth it.  Also be aware there are some special steps involved in uninstalling this plugin, see the guide below.

## Required changes to app.yml

These additions were required for the `pgembeddings` extension which is now deprecated in favour of using `pgvector` which is available as standard within the standard install.

It is important to follow the right path here depending on whether you've previously installed Chatbot or not.

Note, because the (current) lastest version of `pgvector` is now required (>= 0.5.1), new installs require a minor command added to ensure you have the latest version installed.

### I've never installed Chatbot before

Please add the following to app.yml in the `after_code:` section but before the plugins are cloned:

```
    - exec:
        cd: $home
        cmd:
          - su postgres -c 'psql discourse -c "ALTER EXTENSION vector UPDATE;"' 
```

After one succcesful build with the plugin, you should be able to remove these additional lines and should be able to rebuild afterwards without issue.

### I've already installed Chatbot before/have it installed

Please add/ensure you have the following in app.yml in the `after_code:` section but before the plugins are cloned (note that there are three new commands than before):


```
    - exec:
        cd: $home
        cmd:
          - sudo apt-get install wget ca-certificates
    - exec:
        cd: $home
        cmd:
          - wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    - exec:
        cd: $home
        cmd:
          - sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
    - exec:
        cd: $home
        cmd:
          - apt-get update
    - exec:
        cd: $home
        cmd:
          - apt-get -y install -y postgresql-server-dev-${PG_MAJOR}
    - exec:
        cd: $home/tmp
        cmd:
          - git clone https://github.com/neondatabase/pg_embedding.git
    - exec:
        cd: $home/tmp/pg_embedding
        cmd:
          - make PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config
    - exec:
        cd: $home/tmp/pg_embedding
        cmd:
          - make PG_CONFIG=/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config install
    - exec:
        cd: $home
        cmd:
          - su postgres -c 'psql discourse -c "create extension if not exists embedding;"'
    - exec:
        cd: $home
        cmd:
          - su postgres -c 'psql discourse -c "DROP INDEX IF EXISTS hnsw_index_on_chatbot_post_embeddings;"'
    - exec:
        cd: $home
        cmd:
          - su postgres -c 'psql discourse -c "DROP EXTENSION IF EXISTS embedding;"'
    - exec:
        cd: $home
        cmd:
          - su postgres -c 'psql discourse -c "ALTER EXTENSION vector UPDATE;"' 
```

After one succcesful build with the plugin, you should be able to remove these additional lines and should be able to rebuild afterwards without issue.

## Creating the Embeddings

Only necessary if you want to use the agent type bot and ensure it is aware of the content on your forum, not just the current Topic.

Once built, we need to create the embeddings for all posts, so the bot can find forum information.

Enter the container:

`./launcher enter app`

and run the following rake command:

`rake chatbot:refresh_embeddings[1]`

which at present will run twice due to unknown reason (sorry! feel free to PR) but the `[1]` ensures the second time it will only add missing embeddings (ie none immediately after first run).

Compared to bot interactions, embeddings are not expensive to create, but do watch your usage on your Open AI dashboard in any case.

NB Embeddings are only created for Posts and only those Posts for which a Trust Level One user would have access.  This seemed like a reasonable compromise.  It will not create embeddings for posts from Trust Level 2+ only accessible content.

## Bot Type and Model considerations

Take a moment to read through the entire set of Plugin settings.  The `chatbot bot type` setting is key.

Agent mode is superior but will make more calls to the API, potentially increasing cost.  That said, the reduction in its propensity to ultimately output 'hallucinations' may facilitate you being able to drop down from GPT-4 to GPT-3.5 and you may end up spending less despite the significant increase in usefulness and reliability of the output.  GPT 3.5 is also a better fit for the Agent type based on response times.  A potential win-win! Experiment!

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

There's a floating quick chat button that connects you immediately to the bot. Its styling is a little experimental (modifying some z-index values of your base forum on mobile) and it may clash on some pages. This can be disabled in settings.  PR welcome to improve how it behaves.

# Uninstalling the plugin

Due to recent efforts to simplify the plugin, the only step necessary to remove it is to delete the clone statement from your `app.yml`.

**Disclaimer**: I'm *not* responsible for what the bot responds with. Consider the plugin to be at Beta stage and things could go wrong. It will improve with feedback.  But not necessarily the bots response :rofl:  Please understand the pro's and con's of a LLM and what they are and aren't capable of and their limitations.  They are very good at creating convincing text but can often be factually wrong.

**Important Privacy Note**: whatever you write on your forum may get forwarded to Open AI as part of the bots scan of the last few posts once it is prompted to reply (obviously this is restricted to the current Topic or Chat Channel).  Whilst it almost certainly won't be incorporated into their pre-trained models, they will use the data in their analytics and logging.  **Be sure to add this fact into your forum's TOS & privacy statements**.  Related links:  https://openai.com/policies/terms-of-use, https://openai.com/policies/privacy-policy, https://platform.openai.com/docs/data-usage-policies

**Copyright**: Open AI made a statement about Copyright here: https://help.openai.com/en/articles/5008634-will-openai-claim-copyright-over-what-outputs-i-generate-with-the-api
