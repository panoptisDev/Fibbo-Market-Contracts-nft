const mongoose = require("mongoose");

const notificationSchema = mongoose.Schema({
  type: String,
  collectionAddress: String,
  tokenId: Number,
  to: String,
  timestamp: Date,
  params: {},
  visible: Boolean,
});

module.exports = mongoose.model("notifications", notificationSchema);
