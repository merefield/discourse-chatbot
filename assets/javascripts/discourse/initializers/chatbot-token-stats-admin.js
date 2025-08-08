import { withPluginApi } from "discourse/lib/plugin-api";

function initializeChatbotTokenStatsAdmin(api) {
  // Add admin menu item for token statistics
  api.decorateApplicationContent(() => {
    // This will be handled by the admin plugin navigation
  });
}

export default {
  name: "chatbot-token-stats-admin",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (siteSettings.chatbot_enabled) {
      withPluginApi("0.8.31", initializeChatbotTokenStatsAdmin);
    }
  }
};
