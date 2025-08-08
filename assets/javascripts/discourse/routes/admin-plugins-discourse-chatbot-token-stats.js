import ChatbotTokenStats from "../components/chatbot-token-stats";

export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("discourse-chatbot-token-stats", { path: "/discourse-chatbot/token-stats" });
  },
};

export function setupRouter(router) {
  router.map(function() {
    this.route("admin", function() {
      this.route("adminPlugins", { path: "/plugins" }, function() {
        this.route("discourse-chatbot-token-stats", { path: "/discourse-chatbot/token-stats" });
      });
    });
  });
}
