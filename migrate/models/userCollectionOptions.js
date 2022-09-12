const mongoose = require("mongoose");

const userCollection = mongoose.Schema({
  contractAddress: String,
  user: String,
  notShowRedirect: Boolean,
});

module.exports = mongoose.model("usersCollectionsOptions", userCollection);
