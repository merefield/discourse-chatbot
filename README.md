# discourse-chatbot

## Project Sponsors

Our kind sponsors of this project:

| Sponsor | Level | Weblink | Logo |
| --- | --- | --- | --- |
| Surety | Silver Plus | [suretyhome.com](https://suretyhome.com/) | <img src="images/surety.webp" alt="Surety" width="120"> |

# What is it?

* The original Discourse AI Chatbot!
* Converse with the bot in any Post or Chat Channel, one to one or with others!
* Customise the character of your bot to suit your forum!
  * want it to sound like William Shakespeare, or Winston Churchill? can do!
* Configurable tools let the bot:
  * Search your whole* forum for answers so the bot can be an expert on the subject of your forum.
    * not just be aware of the information on the current Topic or Channel.
  * Search Wikipedia
  * Search current news*
  * Search Google*
  * Return current End Of Day market data for stocks.*
  * Evaluate mathematical expressions with Dentaku, including common aliases for PI and E.
* Vision support - select the `vision` tool for the relevant trust levels to let the bot answer questions about uploaded images.
* Image generation and editing support - select the paint tools and choose a supported image model.
* PDF input support can be enabled with `chatbot_support_pdf`.
* Uses the tool-calling capability of cutting-edge, industry-leading large language models through the OpenAI-compatible API.
* Includes a special quota system to manage access to the bot: more trusted and/or paying members can have greater access to the bot!
* Supports OpenAI, Anthropic, Google Gemini, and xAI, plus Azure and OpenAI-compatible proxy connections.

<sup>*sign-up for external (not affiliated) API services required. Links in settings.


The bot has one implementation with a separate built-in tool allowlist for each trust level. Leave
an allowlist empty to expose no built-in tools, or select tools to give that trust level access to
local search and other capabilities. Tools that require credentials or supporting configuration
are only exposed when those requirements are also met. Extension tools supplied by other plugins
are independent of these allowlists.

### :biohazard: **Bot access and privacy :biohazard:

This bot can be used in public spaces on your forum. Local forum search is controlled separately for each bot trust level through the tool settings.

When local forum search is enabled, the bot is governed by `chatbot_embeddings_strategy` (default `benchmark_user`) and is privy to all content the benchmark user can see. Thus, if interacted with in a public-facing Topic, the bot could leak information if you gate sensitive content at that level.

For local forum search, make sure you have a benchmark user at the configured trust level with no additional group membership beyond the automated groups. Bear in mind that the bot can share anything that user can access.

Alternatively:

* Switch `chatbot embeddings strategy` to `categories` and populate `chatbot embeddings categories` with Categories you wish the bot to know about.  (Be aware that if you add any private Categories, it should know about those and anything the bot says in public, anywhere might leak to less privileged users so just be a bit careful on what you add).
* remove `local_forum_search` from the tool settings for trust levels that should not search embedded posts
* mitigate with moderation

You can see that this setup is a compromise.  In order to make the bot useful it needs to be knowledgeable about the content on your site.  Currently it is not possible for the bot to selectively read members only content and share that only with members which some admins might find limiting but there is no way to easily solve the that whilst the bot is able to talk in public. Contact me if you have special needs and would like to sponsor some work in this space. Bot permissioning with semantic search is a non-trivial problem.  The system is currently optimised for speed.  NB Private Messages are never read by the bot.

# FYI's

* LLM API responses can be slower for higher-capability and reasoning models. Choose the model for each trust level based on the quality, latency, and cost your community needs.
* Chatbot natively supports OpenAI, Anthropic, Google Gemini, and xAI through their OpenAI-compatible endpoints, including custom model names and URLs for each trust level. Proxy servers can provide access to other compatible services without changing Chatbot code.
* Is extensible to support the searching of other content beyond just the current set provided.

# Setup

## Creating the Embeddings

If you wish Chatbot to know about the content on your site, turn this setting ON:

`chatbot_embeddings_enabled`

This is only necessary when at least one trust level has the `local_forum_search` tool and the bot should know about content beyond the current Topic.

Initially, we need to create the embeddings for all in-scope posts, so the bot can find forum information.  This now happens in the background once this setting is enabled and you do not need to do anything.

This seeding job can take a period of days for very big sites.

### Embeddings Scope

This is determined by several settings:

* `chatbot_embeddings_strategy` which can be either "benchmark_user" or "categories"
* `chatbot_embeddings_benchmark_user_trust_level` sets the relevant trust level for the former
* `chatbot_embeddings_categories` if the `categories` strategy is set, gives the bot access to consider all posts in specified Categories.

If you change these settings, over time, the population of Embeddings will morph.

### To speed population up

Enter the container:

`./launcher enter app`

and run the following rake command:

`rake chatbot:refresh_embeddings[1]`

which at present will run twice due to unknown reason (sorry! feel free to PR) but the `[1]` ensures the second time it will only add missing embeddings (ie none immediately after first run) so is somewhat moot.

In the unlikely event you get rate limited by OpenAI (unlikely!) you can complete the embeddings by doing this:

`rake chatbot:refresh_embeddings[1,1]`

which will fill in the missing ones (so nothing lost from the error) but will continue more cautiously putting a 1 second delay between each call to OpenAI.

Compared to bot interactions, embeddings are not expensive to create, but do watch your usage on your OpenAI dashboard in any case.

Embeddings are created only for Posts in the scope selected above. The `benchmark_user` strategy uses the configured trust level, while `categories` uses the explicitly selected Categories. Personal Messages are never embedded.

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

For an OpenAI-compatible embedding provider, set
`chatbot_open_ai_embeddings_model_custom_name` to override the built-in model selection and set
`chatbot_open_ai_embeddings_model_custom_url` when the provider uses a different API base URL. The
custom model must return 1,536-dimensional vectors to fit the existing embedding storage.

If you really want to speed the process up, do:

* Change the setting `chatbot_open_ai_embeddings_model` to your new preferred model
* It's best to first delete all your current embeddings:
  * go into the container `./launcher enter app`
  * enter the rails console `rails c`
  * run `::DiscourseChatbot::PostEmbedding.delete_all`
  * `exit` (to return to root within container)
* run `rake chatbot:refresh_embeddings[1]`
* if for any OpenAI-side reason that fails part way through, run it again until you get to 100%
* the new model is known to be more accurate, so you might have to drop `chatbot_forum_search_tool_similarity_threshold` or you might get no results :).  I dropped my default value from `0.8` to `0.6`, but your mileage may vary.

## Blocked questions

Enable `chatbot_blocked_questions_enabled` to compare each incoming question with configured
examples before sending it to the full language model. Add examples and subject labels in
`chatbot_blocked_question_examples`, then tune
`chatbot_blocked_questions_similarity_threshold` to control how closely a question must match.
Matching questions receive a canned decline response containing the configured subject label. If
the semantic check fails, normal bot processing continues. This feature uses the configured
embedding model and endpoint.

## Tools by trust level

The `chatbot_tools_low_trust`, `chatbot_tools_medium_trust`, and
`chatbot_tools_high_trust` settings determine which built-in tools the bot may expose. An empty
selection exposes no built-in tools. Selecting a tool is an allowlist decision; runtime
requirements still apply. For example, `news`, `web_search`, `web_crawler`, and `stock_data` need
their API credentials, while `local_forum_search` needs embeddings to be enabled. Extension tools
provided by other plugins are controlled by those plugins instead.

The defaults are:

* Low and medium trust: `calculate`, `remaining_bot_quota`, and `local_forum_search`.
* High trust: those tools plus `wikipedia`, `news`, `web_crawler`, `web_search`, and `stock_data`.

Runtime requirements still take precedence over these defaults. For example,
`local_forum_search` is exposed only when embeddings are enabled, and tools backed by external
services are exposed only when the required credentials are configured.

The `calculate` tool uses Dentaku expression syntax. It accepts constants such as `PI` and `E`,
normalizes common model-generated forms such as `Math::PI`, and returns correction guidance for
invalid expressions rather than evaluating the same rejected input repeatedly.

For Chatbot to work in Chat you must have Chat enabled.

### Tool extensions

Other plugins can add tools by loading zero-argument subclasses of
`DiscourseChatbot::Tool`. Chatbot discovers subclasses that are not in its built-in tool
list. Trust-level tool settings only control built-in tools and do not affect extension tools.
An extension class may define `self.available?(opts)` to decide at request time whether it should
be exposed; classes without this method remain available by default. If an extension raises while
checking availability or initializing, Chatbot logs the error and omits that extension without
affecting the remaining tools.

## Local chain-of-thought strategies

Requests made through the Chat Completions API can use additional inference-time computation to review or compare an answer before returning it. Configure this with `chatbot_advanced_local_reasoning`:

| Strategy | Behaviour | Additional model calls after the first answer |
| --- | --- | --- |
| `simple` | Uses the existing tool and answer loop without extra local reasoning. This is the default. | None |
| `verify_and_revise` | Asks for a compact review. A corrected answer is generated only when the review identifies a material defect. | One review, plus one conditional revision |
| `best_of_two` | Generates an independent second answer and asks a compact pairwise judge to select the stronger candidate. | One alternative and one judge |
| `uncertainty_guided` | Uses generated-token probabilities to accept a confident first answer immediately. A low-confidence answer is escalated to `best_of_two`. | None when confident; otherwise one alternative and one judge |

For `uncertainty_guided`, `chatbot_advanced_local_reasoning_min_confidence` sets the acceptance threshold from 0 to 100. Confidence is the geometric mean probability of the generated tokens. If an OpenAI-compatible provider does not return log probabilities, the strategy falls back to comparing two answers. If the provider rejects the `logprobs` parameter, the request is retried without it before falling back.

These strategies have several safeguards:

* They apply only to Chat Completions. Reasoning models using the Responses API retain their native reasoning flow.
* Tools run only on the shared initial path. They are disabled for alternative, review, revision, and judge calls, preventing repeated side effects.
* Persisted inner-thought audit posts are excluded from future model context, including when general whispers are included in post history.
* Additional calls count towards `chatbot_chain_of_thought_max_iterations` and `chatbot_open_ai_max_chain_tokens`.
* Revised and alternative answers are checked against any trusted URL provenance collected from tools.
* Usable partial responses produced at the configured completion length limit are returned without additional reasoning.
* If optional reasoning fails, exceeds its available budget, produces malformed control output, or proposes an invalid answer, the already-valid first answer is returned.

The staff-visible inner-thoughts trace records tool calls, the selected advanced strategy, compact review, confidence, and selection information, and the final outcome in chronological order, including safe fallbacks. It also includes aggregate input, output, cache, and provider-reported reasoning token statistics for the complete response. These statistics are accumulated outside the model context and are only merged into the persisted audit entry after generation finishes. It does not request or expose a model's hidden chain-of-thought.

### Token, tool, and URL limits

`chatbot_max_response_tokens` limits visible output for non-reasoning Chat Completions requests,
while `chatbot_open_ai_max_reasoning_output_tokens` limits the combined reasoning and visible output
for Responses API requests. `chatbot_open_ai_max_chain_tokens`,
`chatbot_chain_of_thought_max_iterations`, and `chatbot_chain_of_thought_max_tool_calls` cap the
overall tool loop. `chatbot_tool_response_char_limit` caps content returned by web tools before it
is included in a later model request.

When `chatbot_url_integrity_check` is enabled, Chatbot checks generated URLs against trusted URLs
from the conversation and tool results. `chatbot_chain_of_thought_max_url_repair_attempts` controls
how many times the model may repair an unsupported URL before the response is rejected.

### References

* [Scaling LLM Test-Time Compute Optimally can be More Effective than Scaling Model Parameters](https://arxiv.org/abs/2408.03314) motivates adaptive allocation of inference-time compute and compares search strategies with best-of-N sampling.
* [Self-Refine: Iterative Refinement with Self-Feedback](https://arxiv.org/abs/2303.17651) describes the generate, self-review, and revise pattern behind `verify_and_revise`.
* [Self-Consistency Improves Chain of Thought Reasoning in Language Models](https://arxiv.org/abs/2203.11171) establishes the value of sampling multiple reasoning paths rather than relying on one greedy answer.
* [Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena](https://arxiv.org/abs/2306.05685) studies model-based pairwise evaluation and its biases, informing the compact judge used by `best_of_two`.
* [Semantic Uncertainty: Linguistic Invariances for Uncertainty Estimation in Natural Language Generation](https://arxiv.org/abs/2302.09664) motivates uncertainty-aware escalation. The plugin uses a cheaper token-probability signal rather than semantic entropy.

## Bot's speed of response

This is governed mostly by a setting: `‎chatbot_reply_job_time_delay‎` over which you have discretion.

The intention of having this setting is to:

* protect you from reaching rate limits of OpenAI
* protect your site from users that would like to spam the bot and cost you money.

It is now default '1' second and can now be reduced to zero :racing_car: , but be aware of the above risks.

Setting this to zero can make the bot, including tool-enabled conversations, feel much more responsive.

Obviously this can be a bit artificial and no real person would actually type that fast ... but set it to your taste and wallet size.

Chatbot cannot directly control provider response time. Higher-capability models, greater reasoning effort, advanced local reasoning, and multi-step tool use can all increase latency.

For Chatbot to work in Chat you must have Chat enabled.

## LLM provider

Select OpenAI, Anthropic, Google Gemini, or xAI with `chatbot_llm_provider`, then configure its API key in the provider-specific token setting shown below it. Existing OpenAI keys remain in `chatbot_open_ai_token`; the other providers use `chatbot_anthropic_token`, `chatbot_google_gemini_token`, and `chatbot_x_ai_token`. Each provider uses its official OpenAI-compatible endpoint.

The language model is selected independently for low-, medium-, and high-trust users. Each trust level shows a model dropdown for the active provider and hides the other providers' dropdowns. The defaults are GPT-4.1 Mini, Claude Sonnet 5, Gemini 3.7 Flash, and Grok 4.6. Custom model settings override the active dropdown and custom URLs override the provider's default endpoint for the selected trust level. A custom endpoint must implement the selected provider's OpenAI-compatible API shape and receives that provider's key. Azure remains available through the custom OpenAI API settings.

Embedding models and endpoints are configured separately and continue to use `chatbot_open_ai_token`. Anthropic does not provide an embedding API, and custom embedding providers must return 1,536-dimensional vectors to fit the existing embedding storage. Image generation and editing also continue to use the OpenAI key, independently of the selected chat provider.

There is an automated part of the setup: upon addition to a Discourse, the plugin currently sets up an AI bot user with the following attributes

* Name: 'Chatbot'
* User Id: -4
* Bio: "Hi, I’m not a real person. I’m a bot that can discuss things with you. Don't take me too seriously.  Sometimes, I'm even right about stuff!"
* Group Name: "ai_bot_group"
* Group Full Name: "AI Bots"

You can edit the name, avatar and bio (see locale string in admin -> customize -> text) as you wish but make it easy to mention.

## It's not free, so there's a quota system, and you have to set this up

Initially **no-one** will have access to the bot, not even staff.

Calling the OpenAI API is not free after an initial free allocation has expired! So, I've implemented a quota system to keep this under control, keep costs down and prevent abuse.  The cost is not crazy with these small interactions, but it may add up if it gets popular. You can read more about OpenAI pricing [on their pricing page](https://openai.com/pricing).

In order to interact with the bot you must belong to a group that has been added to one of the three levels of trusted sets of groups, low, medium & high trust group sets. You can modify each of the number of allowed interactions per week per trusted group sets in the corresponding settings.

You must populate the groups too. That configuration is entirely up to you. They start out blank,
so initially **no-one** will have access to the bot. Set `chatbot_quota_basis` to enforce either
query or token quotas, then configure the corresponding quota for each trust level.

Note the user gets the quota based on the highest trusted group they are a member of.

## "Prompt Engineering"

There are several locale text "settings" that influence what the bot receives and how the bot responds.

The most important one you should consider changing is the bot's `system` prompt.  This is sent every time you speak to the bot.

For example, you can try a system prompt like:

’You are an extreme Formula One fan, you love everything to do with motorsport and its high octane levels of excitement’ instead of the default.

Keep the tool-use instructions after "You are a helpful assistant." when tools are selected, or you may break agent behaviour. Reset the prompt if you run into problems.

Try one that is most appropriate for the subject matter of your forum.  Be creative!

Changing these locale strings can make the bot behave very differently but cannot be amended on the fly.  I would recommend changing only the system prompt as the others play an important role in agent behaviour or providing information on who said what to the bot.

NB In Topics, the first Post and Topic Title are sent in addition to the window of Posts (determined by the lookback setting) to give the bot more context.

You can edit these strings in Admin -> Customize -> Text under `chatbot.prompt.`

[View the chatbot prompt text in the server locale file.](config/locales/server.en.yml)

# Supports both Posts & Chat Messages!

The bot supports Chat Messages and Topic Posts, including Private Messages (if configured).

You can prompt the bot to respond by replying to it, or @ mentioning it. You can set how far the bot looks behind to get context for a response. The bigger the value the more costly will be each call.

There's a floating quick chat button that connects you immediately to the bot. This can be disabled in settings. You can choose whether to load the bot into a 1 to 1 chat or a Personal Message.

Now you can choose your preferred icon (default :robot: ) or if setting left blank, will pick up the bot user's avatar! :sunglasses: 

And remember, you can also customise the text that appears when it is expanded by editing the locale text using Admin -> Customize -> Text `chatbot.`

# Uninstalling the plugin

The only step necessary to remove it is to delete the clone statement from your `app.yml`.

# Disclaimer

I'm *not* responsible for what the bot responds with. Consider the plugin to be at Beta stage and things could go wrong. It will improve with feedback.  But not necessarily the bots response :rofl:  Please understand the pro's and con's of a LLM and what they are and aren't capable of and their limitations.  They are very good at creating convincing text but can often be factually wrong.

# Privacy Note

Whatever you write on your forum may be forwarded to OpenAI or your configured model provider as part of the conversation context or a tool request. Local forum search may also provide matching embedded Posts within the configured scope. **Be sure to cover this in your forum's terms of service and privacy statements.** Related links: https://openai.com/policies/terms-of-use, https://openai.com/policies/privacy-policy, https://platform.openai.com/docs/data-usage-policies

# Copyright

OpenAI made a statement about Copyright here: https://help.openai.com/en/articles/5008634-will-openai-claim-copyright-over-what-outputs-i-generate-with-the-api
