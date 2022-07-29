const mongoose = require("mongoose");

const profileSchema = mongoose.Schema({
  wallet: String,
  username: String,
  profileImg: String,
  profileBanner: String,
  followers: Array,
  following: Array,
  ftmSended: Boolean,
  verified: Boolean,
});

module.exports = mongoose.model("profiles", profileSchema);
