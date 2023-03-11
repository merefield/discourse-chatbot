# frozen_string_literal: true
chatbot_name = 'AIBot'
group_name = "ai_bot_group"
group_full_name = "AI Bots"

user = User.find_by(id: -4)
group = Group.find_by(id: -4)

if !user
  suggested_username = UserNameSuggester.suggest(chatbot_name)

  UserEmail.seed do |ue|
    ue.id = -4
    ue.email = "not@atall.valid"
    ue.primary = true
    ue.user_id = -4
  end

  User.seed do |u|
    u.id = -4
    u.name = chatbot_name
    u.username = suggested_username
    u.username_lower = suggested_username.downcase
    u.password = SecureRandom.hex
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[4]
    u.admin = true
  end

end

if !group
  Group.seed do |g|
    g.id = -4
    g.name = group_name
    g.full_name = group_full_name
  end

  GroupUser.seed do |gu|
    gu.user_id = -4
    gu.group_id = -4
  end

  SiteSetting.chat_allowed_groups += "|-4"
end

bot = User.find(-4)

bot.user_option.update!(
  email_messages_level: 0,
  email_level: 2
)

if !bot.user_profile.bio_raw
  bot.user_profile.update!(
    bio_raw: I18n.t('chatbot.bio', site_title: SiteSetting.title, chatbot_username: bot.username)
  )
end
