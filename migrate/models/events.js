const mongoose = require("mongoose");

const eventSchema = mongoose.Schema({
  eventType: String,
  tokenId: Number,
  collectionAddress: String,
  from: String,
  to: String,
  timestamp: Date,
  price: Number,
});

module.exports = mongoose.model("events", eventSchema);
