const mongoose = require("mongoose");

const suggestionsSchema = mongoose.Schema({
  proposer: String,
  title: String,
  description: String,
});

module.exports = mongoose.model("suggestions", suggestionsSchema);
