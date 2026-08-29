# discourse-chatbot

This README is the canonical reference for installing, configuring, operating, and troubleshooting Chatbot.

## Project sponsors

Our kind sponsors of this project:

| Sponsor | Level | Weblink | Logo |
| --- | --- | --- | --- |
| Surety | Silver Plus | [suretyhome.com](https://suretyhome.com/) | <img src="images/surety.webp" alt="Surety" width="120"> |

# What is it?

* The original Discourse AI Chatbot!
* Can provide customer-support answers grounded in your community content; see [Building a technical support chatbot](https://meta.discourse.org/t/building-a-technical-support-chatbot/319825?u=merefield).
* Converse with the bot in Topics, Personal Messages, Chat channels, and Chat threads, one-to-one or with others!
* Customise the character of your bot to suit your forum!
  * want it to sound like William Shakespeare, or Winston Churchill? can do!
* Configurable tools let the bot:
  * Search your forum for answers so the bot can be an expert on the subject of your community.
    * not just be aware of the information on the current Topic or Channel.
  * Search Wikipedia
  * Search current news*
  * Search Google*
  * Return current End Of Day market data for stocks.*
  * Evaluate mathematical expressions with Dentaku, including common aliases for PI and E.
  * Collect outstanding editable User Fields in private conversations.
  * Escalate a private Chat conversation to configured staff groups.
* Vision support - select the `vision` tool for the relevant trust levels to let the bot answer questions about uploaded images.
* Image generation and editing support - select the paint tools and choose a supported image model.
* OpenAI PDF input support can be enabled with `chatbot_support_pdf`.
* Uses the tool-calling capabilities of OpenAI, Anthropic, Google Gemini, and xAI models through their OpenAI-compatible APIs.
* Includes a special quota system to manage access to the bot: more trusted and/or paying members can have greater access to the bot!
* Supports OpenAI, Anthropic, Google Gemini, and xAI, plus Azure and OpenAI-compatible proxy connections.

<sup>*Sign-up for external, unaffiliated API services is required. Links are provided in the settings.</sup>


The bot has one implementation with a separate built-in tool allowlist for each trust level. Leave
an allowlist empty to expose no built-in tools, or select tools to give that trust level access to
local search and other capabilities. Tools that require credentials or supporting configuration
are only exposed when those requirements are also met. Extension tools supplied by other plugins
are independent of these allowlists.

### :biohazard: **Bot access and privacy** :biohazard:

This bot can be used in public spaces on your forum. Local forum search is controlled separately for each bot trust level through the tool settings.

When local forum search is enabled, the bot is governed by `chatbot_embeddings_strategy` (default `benchmark_user`) and is privy to all content the benchmark user can see. Thus, if interacted with in a public-facing Topic, the bot could leak information if you gate sensitive content at that level.

For local forum search, make sure you have a benchmark user at the configured trust level with no additional group membership beyond the automated groups. Bear in mind that the bot can share anything that user can access.

Alternatively:

* Set `chatbot_embeddings_strategy` to `categories` and populate `chatbot_embeddings_categories` with only the Categories the bot may search. Including private Categories means their matching content could be returned to less-privileged users elsewhere.
* Remove `local_forum_search` from any trust-level tool allowlist that should not search embedded content.
* Use moderation and carefully scoped groups as additional safeguards.

This is a deliberate compromise: semantic search is optimised for speed and does not perform a fresh per-request visibility check for the person asking the bot. Private Messages are never embedded. Contact me if you need a more restrictive permission model and would like to sponsor that work.

# Notes

* LLM API responses can be slower for higher-capability and reasoning models. Choose the model for each trust level based on the quality, latency, and cost your community needs.
* Chatbot natively supports OpenAI, Anthropic, Google Gemini, and xAI through their OpenAI-compatible endpoints, including custom model names and URLs for each trust level. Proxy servers can provide access to other compatible services without changing Chatbot code.
* Other plugins can extend the toolset without maintaining a fork of Chatbot.

# Setup

For a new installation, configure [model providers](#model-providers), [access and quotas](#access-and-quotas), and [trust-level tools](#tools-by-trust-level) first. Stored forum embeddings are optional and are needed for local forum search. Blocked-question matching uses the configured embeddings provider without requiring the stored forum index.

## Prerequisites

Install the plugin using the [standard self-hosted plugin procedure](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157).

Local forum search requires PostgreSQL's `pgvector` extension, version 0.5.1 or newer. Most supported Discourse installations already provide it. If a rebuild fails with `PG::UndefinedObject: ERROR: access method "hnsw" does not exist`, enter the running container and update the extension:

```text
./launcher enter app
su postgres -c 'psql discourse'
\dx
ALTER EXTENSION vector UPDATE;
\dx
\q
exit
```

Then leave the container and rebuild the app.

## Creating the embeddings

If you wish Chatbot to know about the content on your site, turn this setting ON:

`chatbot_embeddings_enabled`

This is only necessary when at least one trust level has the `local_forum_search` tool and the bot should know about content beyond the current Topic.

Initially, Chatbot creates embeddings for all in-scope Posts and Topic titles so the bot can find forum information. This happens in the background after the setting is enabled.

This seeding job can take a period of days for very big sites.

### Embeddings scope

This is determined by several settings:

* `chatbot_embeddings_strategy`, which can be either `benchmark_user` or `categories`;
* `chatbot_embeddings_benchmark_user_trust_level`, which sets the relevant trust level for `benchmark_user`;
* `chatbot_embeddings_categories`, which identifies the Categories included by the `categories` strategy.

When these settings change, background jobs gradually bring the stored embeddings into the new scope.

### To speed population up

Enter the container:

`./launcher enter app`

and run the following rake command to fill missing embeddings:

`rake chatbot:refresh_embeddings[1]`

If the selected provider rate-limits requests, add a one-second delay:

`rake chatbot:refresh_embeddings[1,1]`

Embedding costs vary by provider and model. Monitor usage and billing in the dashboard for your selected embeddings provider.

Embeddings are created only for Posts in the scope selected above. The `benchmark_user` strategy uses the configured trust level, while `categories` uses the explicitly selected Categories. Personal Messages are never embedded.

### Useful Data Explorer query to monitor embeddings population

@37Rb writes: "Here’s a SQL query I’m using with the [Data Explorer](https://meta.discourse.org/t/discourse-data-explorer/32566) plugin to monitor & verify embeddings… in case it helps anyone else."

```
SELECT e.id, e.post_id AS post, p.topic_id AS topic, p.post_number,
       e.provider, e.model, e.created_at, e.updated_at,
       p.deleted_at AS post_deleted
FROM chatbot_post_embeddings e LEFT JOIN posts p ON e.post_id = p.id
```

### Embedding input is too long

You might get an error like this:

```
OpenAI HTTP Error (spotted in ruby-openai 6.3.1): {"error"=>{"message"=>"This model's maximum context length is 8192 tokens, however you requested 8528 tokens (8528 in your prompt; 0 for the completion). Please reduce your prompt; or completion length.", "type"=>"invalid_request_error", "param"=>nil, "code"=>nil}}
```
In this example, the embedding model has a limit of:

`8192 tokens`

`however you requested 8528`

Reduce the current value of this legacy-named setting, which applies to every embeddings provider:

`chatbot_open_ai_embeddings_char_limit`

As a starting point for English text, multiply the token difference by roughly four characters.

So, in this example, 4 x (8528 - 8192) = 1344

Dropping `chatbot_open_ai_embeddings_char_limit` by about 1,500 would therefore be a cautious first adjustment. Tokenisation varies by provider, model, and language, so lower it further if the error continues.

### Switching embeddings provider or model

Select `chatbot_embeddings_provider`, then choose the model shown for that provider. OpenAI, Google Gemini, and xAI are supported; Anthropic does not provide an embeddings API. The selected provider reuses its provider-specific API key.

Changing the embeddings provider or model automatically makes older Post and Topic-title vectors invalid. Background jobs gradually regenerate them with the new configuration, so you do not need to delete them manually.

For a custom embeddings service, set `chatbot_open_ai_embeddings_model_custom_name` and, when required, `chatbot_open_ai_embeddings_model_custom_url`. The endpoint must implement the selected provider's embeddings API shape and return exactly 1,536 dimensions.

To refresh every in-scope embedding immediately, enter the container and run:

```text
rake chatbot:refresh_embeddings
```

Use `rake chatbot:refresh_embeddings[1]` only to fill missing rows. Add a positive delay as the second argument, for example `rake chatbot:refresh_embeddings[1,1]`, if the provider rate-limits requests.

### Tuning local forum search

`chatbot_forum_search_tool_similarity_threshold` controls the minimum semantic similarity and
`chatbot_forum_search_tool_max_results` limits the result count. If a new embeddings model returns
few useful results, retune the threshold rather than assuming scores are directly comparable with
the previous model.

Search can return individual Posts or Topics, optionally include Topic-title embeddings, and blend
Discourse keyword search with semantic search. Group and Tag promotion settings can promote matches
from preferred authors or Topics without restricting the embedding scope to them. These controls affect relevance;
they do not add per-request permissions beyond the configured embedding scope.

## How to get the bot to respond

The bot supports Topic Posts, Personal Messages, Chat channels, and Chat threads when those surfaces are enabled in Discourse and allowed in Chatbot settings.

* Subject to permissions and quota, the bot responds when it is @mentioned.
* In a Topic or Chat conversation containing only the bot and one other user, it can respond without an @mention.
* Replying directly to the bot can invoke it.
* `chatbot_max_look_behind` controls how much prior conversation context is sent, which affects cost.
* `chatbot_permitted_all_categories` and `chatbot_permitted_categories` control Topic availability.
* `chatbot_permitted_in_private_messages` and `chatbot_permitted_in_chat` control those surfaces.

### Category auto-responder

Categories listed in `chatbot_auto_respond_categories` can receive an automatic reply to each new Topic. Configure the Category-specific additional prompt in that Category's settings.

Write that prompt as the user's request, not as a replacement system prompt. For example:

> Welcome me, introduce yourself, and use local forum search to share five relevant forum Topics with links.

### Optional User Fields collection

Add `user_information` to the relevant trust-level tool allowlist to let the bot collect outstanding editable User Fields in private conversations. Text, dropdown, and confirmation fields are supported; multi-select fields are not.

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

The `user_information` tool is available only in private conversations. The `escalate_to_staff`
tool is available only in private Chat and creates a staff Personal Message containing the
configured amount of conversation history. More tools can improve grounding and task coverage,
but tool loops may add latency and provider cost.

External tools use separate service credentials:

* `news` requires `chatbot_news_api_token`;
* `web_crawler` uses Firecrawl or Jina;
* `web_search` uses SerpAPI or Jina; and
* `stock_data` requires a Marketstack key.

The relevant key and notional quota-cost settings are hidden from the model and documented in the
admin settings UI.

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

* protect you from reaching the selected provider's rate limits
* protect your site from users that would like to spam the bot and cost you money.

It defaults to two seconds and can be reduced to zero :racing_car:, but be aware of the above risks.

Setting this to zero can make the bot, including tool-enabled conversations, feel much more responsive.

Obviously this can be a bit artificial and no real person would actually type that fast ... but set it to your taste and wallet size.

Chatbot cannot directly control provider response time. Higher-capability models, greater reasoning effort, advanced local reasoning, and multi-step tool use can all increase latency.

For Chatbot to work in Chat you must have Chat enabled.

## Model providers

Choose providers independently for language-model replies, embeddings, vision, and image generation. Each capability uses the API key belonging to its selected provider.

| Capability | OpenAI | Anthropic | Google Gemini | xAI |
| --- | --- | --- | --- | --- |
| LLM replies and tools | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Embeddings | :white_check_mark: | — | :white_check_mark: | :white_check_mark: |
| Vision | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Image generation | :white_check_mark: | — | :white_check_mark: | :white_check_mark: |
| Image editing | GPT Image models | — | — | :white_check_mark: |
| PDF conversation input | :white_check_mark: | — | — | — |

Select the reply provider with `chatbot_llm_provider`, then enter its key in `chatbot_open_ai_token`, `chatbot_anthropic_token`, `chatbot_google_gemini_token`, or `chatbot_x_ai_token`. Keys are available from [OpenAI](https://platform.openai.com/api-keys), [Anthropic](https://console.anthropic.com/settings/keys), [Google AI Studio](https://aistudio.google.com/app/apikey), and the [xAI Console](https://console.x.ai). Provider-specific keys are intentionally retained, so changing one capability's provider does not require copying credentials into a generic key.

The language model is selected independently for low-, medium-, and high-trust users. The settings UI displays only the active provider's model dropdowns. The lists contain stable model names rather than dated snapshot variants; use the custom-model option when you need another model.

`chatbot_embeddings_provider`, `chatbot_vision_provider`, and `chatbot_image_provider` select providers for those capabilities independently of the reply provider. Their model settings are likewise shown only for the selected provider.

Leave a custom URL blank to use Chatbot's built-in official endpoint for the selected provider. Generation controls for temperature, top-p, frequency penalty, and presence penalty are shown only for OpenAI and xAI, whose supported API shapes accept them. `chatbot_api_supports_name_attribute` is OpenAI-only and should remain disabled for custom endpoints unless they explicitly document support. OpenAI reasoning and Responses API settings are hidden for the other providers.

### Quick OpenAI example

1. Create an [OpenAI API key](https://platform.openai.com/api-keys) and ensure API billing is enabled.
2. Set `chatbot_llm_provider` to OpenAI and paste the key into `chatbot_open_ai_token`.
3. Leave the custom URL blank, choose an OpenAI model for each trust level you intend to use, and add your test group to the matching Chatbot access setting.
4. Mention the bot in an allowed Topic, Personal Message, or Chat to test it.

### Custom endpoints, proxies, Azure, and local models

Custom names and URLs let Chatbot use services that implement one of the supported providers' API shapes. Select the provider shape the service emulates, enable the custom model for each applicable trust level, enter the exact model name, and set the custom URL. The provider-specific key for the selected shape is sent to that endpoint.

This supports OpenAI-compatible services such as many proxies and local model servers, including Ollama when its OpenAI-compatible endpoint is enabled. Endpoint paths differ between services, so use the base URL documented by that service—commonly a URL ending in `/v1/`—rather than assuming one universal Ollama or proxy URL.

Azure OpenAI remains available through the OpenAI custom URL, API type, and API version settings. Custom embeddings, vision, and image endpoints have separate URL overrides. Compatibility depends on the endpoint implementing the request and response fields used by the selected capability.

## Bot user

When installed, the plugin creates an AI bot user with these initial attributes:

* Name: 'Chatbot'
* User ID: -4
* Bio: "Hi, I’m not a real person. I’m a bot that can discuss things with you. Don't take me too seriously.  Sometimes, I'm even right about stuff!"
* Group Name: "ai_bot_group"
* Group Full Name: "AI Bots"

You can edit the name, avatar and bio (see locale string in admin -> customize -> text) as you wish but make it easy to mention.

## Access and quotas

Initially **no one** has access to the bot, including staff. Assign groups to the low-, medium-, or high-trust Chatbot group settings. A user receives the model, tools, and quota associated with their highest matching Chatbot trust level.

Hosted model APIs are generally metered services, so Chatbot includes quotas to control access, cost, and abuse. Set `chatbot_quota_basis` to enforce either query or token quotas, then configure the allowance for each trust level. Check the pricing documentation for every provider and model you enable.

## Prompt engineering

There are several locale text "settings" that influence what the bot receives and how the bot responds.

The most important one you should consider changing is the bot's `system` prompt.  This is sent every time you speak to the bot.

For example, you can try a system prompt like:

> You are an extreme Formula One fan. You love everything to do with motorsport and its high-octane excitement.

Keep the tool-use instructions after "You are a helpful assistant." when tools are selected, or you may break agent behaviour. Reset the prompt if you run into problems.

Try one that is most appropriate for the subject matter of your forum.  Be creative!

Changing these locale strings can make the bot behave very differently. They apply globally to future requests rather than acting as per-conversation controls. I recommend changing only the system prompts because the other prompt strings play important roles in tool behavior and conversation attribution.

There are separate `open` and `private` system prompts. The open prompt is used in public Topics and Chat channels; the private prompt is used in Personal Messages and direct-message Chat. Keep the tool-use instructions intact whenever the corresponding trust level has tools enabled.

NB In Topics, the first Post and Topic Title are sent in addition to the window of Posts (determined by the lookback setting) to give the bot more context.

You can edit these strings in Admin -> Customize -> Text under `chatbot.prompt.`

[View the chatbot prompt text in the server locale file.](config/locales/server.en.yml)

# Posts and Chat messages

The bot supports Chat Messages and Topic Posts, including Private Messages (if configured).

You can prompt the bot to respond by replying to it, or @ mentioning it. You can set how far the bot looks behind to get context for a response. The bigger the value the more costly will be each call.

There's a floating quick-access button that connects you immediately to the bot. Configure it with `chatbot_quick_access_talk_button`, choose whether the bot starts the conversation with `chatbot_quick_access_bot_kicks_off`, and optionally choose an icon with `chatbot_quick_access_talk_button_bot_icon`. If the icon is blank, Chatbot uses the bot user's avatar.

And remember, you can also customise the text that appears when it is expanded by editing the locale text using Admin -> Customize -> Text `chatbot.`

# Debugging

For temporary diagnostics:

* enable `chatbot_include_inner_thoughts_in_private_messages` when testing privately;
* set `chatbot_enable_verbose_rails_logging` to `api_calls_only` or `all`;
* choose the warning log destination if you need entries to appear in the Discourse `/logs` interface;
* reproduce the request, then inspect the Sidekiq job exception and Rails logs immediately;
* never publish API keys or unredacted request headers.

The provider's HTTP status and response body are usually more useful than the final Ruby stack trace. Custom endpoints should be checked against the API shape selected in Chatbot.

# Extending Chatbot's toolset with plugins

Other plugins can add tools without maintaining a fork of Chatbot. See the [function-extension example](https://github.com/merefield/discourse-chatbot-function-extension-example) and the [original extension pull request](https://github.com/merefield/discourse-chatbot/pull/117).

Extension tools subclass `DiscourseChatbot::Tool`. They may implement `self.available?(opts)` for request-time availability. Trust-level allowlists control built-in tools; an extension plugin remains responsible for the permissions and configuration of its own tools.

# Known limitations and possible roadmap

* Semantic search permissions are based on the configured embedding scope, not on each person asking the bot.
* User Fields collection does not support multi-select fields.
* Custom endpoints vary in their support for tools and optional request attributes.
* Bot typing indicators and streamed responses remain potential future improvements.
* Responding to edits that add a missing @mention remains potential future work.

# Credits

* Thanks to @MarcP for enthusiastic support and detailed testing feedback.
* Thanks to contributors to [ruby-openai](https://github.com/alexrudall/ruby-openai), which provides the shared OpenAI-compatible client.
* The floating button design was based on Discourse's [Material Design Stock Theme](https://github.com/discourse/material-design-stock-theme).
* The original fixtures code was based on work from [discourse-autobot](https://github.com/VinkasHQ/discourse-autobot).
* Thanks to @P16, whose early chatbot work helped inspire this plugin.

# Uninstalling the plugin

Remove the plugin's clone statement from `app.yml`, then rebuild the Discourse container. Plugin database tables are retained unless you remove them separately.

# Disclaimer

I'm *not* responsible for the bot's responses. Consider the plugin to be at beta stage; things can go wrong. Understand the strengths, limitations, and risks of LLMs before enabling it. They can generate convincing text that is factually wrong.

# Privacy note

Conversation content, uploaded media, and tool results may be sent to the providers selected for LLM replies, vision, images, embeddings, or external tools. Local forum search may send matching embedded Posts from the configured scope to the reply provider. Review every selected provider's retention and data-use terms, and disclose this processing in your forum's terms of service and privacy notice.

# Copyright

Generated-output terms differ by provider and jurisdiction. Review the terms for every provider you enable. OpenAI's related guidance is available in [Will OpenAI claim copyright over what outputs I generate with the API?](https://help.openai.com/en/articles/5008634-will-openai-claim-copyright-over-what-outputs-i-generate-with-the-api)
