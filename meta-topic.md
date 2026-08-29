||||
-|-|-|
:information_source: | **Summary** | The Original AI Chatbot for Discourse
:hammer_and_wrench: | **Repository** | https://github.com/merefield/discourse-chatbot
:books: | **Documentation** | [Full setup, configuration, and troubleshooting guide](https://github.com/merefield/discourse-chatbot#readme)
:open_book: | **Install guide** | [How to install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157)
:heart: | **Sponsorship** | Please consider becoming an ongoing [sponsor of my open source work](https://github.com/sponsors/merefield) at a level that suits your or your organisation's resources and needs.

Enjoying this plugin? Please :star: it on [GitHub](https://github.com/merefield/discourse-chatbot)! :pray:

![Chatbot demonstration|690x394](upload://8EwO5GnzjrxSVcKfb7w7u45RqHc.jpeg)

> :information_source: This is an independently contributed plugin. Please make support, bug, UX, and feature requests in this topic. It is not available on Discourse-hosted plans. You can install it when self-hosting and may be able to use it with third-party hosting; check with your provider.

# The original AI Chatbot for Discourse

Chatbot brings configurable AI conversations to Topics, Personal Messages, Chat channels, and Chat threads. Give the bot a character that suits your community, decide which groups may use it, and choose different models and tools for low-, medium-, and high-trust users.

It can:

* answer normally from the current conversation;
* search selected forum content with semantic or hybrid search;
* search Wikipedia, current news, and the web;
* crawl remote pages and retrieve end-of-day market data;
* perform reliable expression-based calculations;
* see uploaded images and optionally read PDFs;
* generate and edit images;
* collect outstanding editable User Fields in private conversations;
* escalate private Chat conversations to configured staff groups;
* respond automatically to new Topics in selected Categories; and
* accept additional tools supplied by other plugins.

For a practical support workflow, see [Building a technical support chatbot](https://meta.discourse.org/t/building-a-technical-support-chatbot/319825?u=merefield).

With local forum search enabled, the bot can ground answers in your community's content:

![Local forum search example|687x500](upload://3cXbuZgs98qZPwvmHyLB1RSzaAv.png)

For simpler conversations, expose fewer or no tools to reduce calls, latency, and cost:

![Conversation without local forum search|640x500](upload://6bOtm7eOPi8esCHio3CvfPphYlP.png)

## Provider support

Choose providers independently for replies, embeddings, vision, and image generation. Each capability reuses the API key belonging to its selected provider.

| Capability | OpenAI | Anthropic | Google Gemini | xAI |
| --- | --- | --- | --- | --- |
| LLM replies and tools | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Embeddings | :white_check_mark: | — | :white_check_mark: | :white_check_mark: |
| Vision | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Image generation | :white_check_mark: | — | :white_check_mark: | :white_check_mark: |
| Image editing | GPT Image models | — | — | :white_check_mark: |
| PDF conversation input | :white_check_mark: | — | — | — |

If no custom URL is set, Chatbot uses its built-in official endpoint for the selected provider. Custom model names and URLs support Azure OpenAI, Ollama, proxies, and other services that implement a supported provider's API shape.

Provider-specific model dropdowns are shown only when that provider is active. The reply model can differ by trust level, while embeddings, vision, and image generation each have their own provider and model selector.

[Read the full provider and custom-endpoint guide](https://github.com/merefield/discourse-chatbot#model-providers).

## Access, quotas, and tools

Nobody has access until you assign groups to Chatbot's low-, medium-, or high-trust group settings. Users inherit the quota, model, and tool allowlist of their highest matching Chatbot trust level. Quotas can be measured by queries or tokens.

Built-in tools are selected independently for each trust level. Credentials and supporting settings still control runtime availability, so selecting a web tool without its API key does not expose it.

Read about [access and quotas](https://github.com/merefield/discourse-chatbot#access-and-quotas) and [trust-level tools](https://github.com/merefield/discourse-chatbot#tools-by-trust-level).

## Local forum search and privacy

:biohazard: **Please understand the embedding scope before enabling local forum search.**

The default `benchmark_user` strategy embeds content visible to a suitable user at the configured trust level. The `categories` strategy embeds content from explicitly selected Categories. Semantic search is optimised for speed and does not repeat a visibility check for every person asking the bot, so matching content may be shared outside its original audience if the scope includes restricted content.

Private Messages are never embedded. Keep the benchmark trust level low, avoid private Categories unless their contents may be disclosed to every Chatbot user, and remove `local_forum_search` from trust levels that should not use it.

The selected providers may receive conversation content, uploads, embedded search matches, and tool results. Review their retention and data-use terms, and disclose this processing in your forum's terms and privacy notice.

[Read the full embeddings, scope, and privacy guide](https://github.com/merefield/discourse-chatbot#creating-the-embeddings).

## Quick start

1. Install the plugin using the normal self-hosted plugin procedure.
2. Select `chatbot_llm_provider`, enter that provider's API key, and choose models for each trust level.
3. Add groups to the low-, medium-, or high-trust access settings and configure quotas.
4. Choose the built-in tools available to each trust level.
5. If you enable `local_forum_search`, configure its embedding provider and carefully review its scope.
6. Mention the bot, reply to it, use the quick-access button, or configure a Category auto-response prompt.

The repository README is the source of truth for prerequisites, every major setting group, provider-specific behavior, custom endpoints, embedding maintenance, prompt customization, debugging, extension development, and uninstalling:

:books: **[Open the complete README](https://github.com/merefield/discourse-chatbot#readme)**

## Selected UI features

Categories can welcome a new Topic and ask the bot to search for relevant community content:

![Category auto-response configuration|613x102](upload://pxBYWGlvHmdkPzt1JNTxj1QPVgb)

The optional quick-access button can open a direct Chat or Personal Message with the bot:

![Quick-access Chatbot button|319x204](upload://7ipqsrkJzSdFS1Vut0kAifXDSJn.png)

The User Fields tool can collect supported empty fields privately:

![User Fields collection|690x73](upload://3dparFKbiiRoyp0tG7gdG62198h.png)

## Support and sponsorship

Please report support requests, bugs, UX feedback, and feature ideas in this Meta topic. Include the provider, model name, relevant settings, HTTP status and provider response body, while removing API keys and private content.

This work depends on community support. If the plugin is valuable to your site, please [sponsor its ongoing maintenance](https://github.com/sponsors/merefield).

## Project sponsors

| Sponsor | Level | Website |
| --- | --- | --- |
| Surety | Silver Plus | [suretyhome.com](https://suretyhome.com/) |

## Disclaimer

LLMs can produce convincing but incorrect output. Test the plugin against your community's needs, understand the privacy and cost implications, and apply appropriate moderation. Generated-output terms differ by provider and jurisdiction; review the terms for every provider you enable.
