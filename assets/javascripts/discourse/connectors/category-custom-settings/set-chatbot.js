export default {
  setupComponent(attrs) {
    if (!attrs.category.custom_fields) {
      attrs.category.custom_fields = {};
    }
  },
};
