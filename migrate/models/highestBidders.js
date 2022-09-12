const mongoose = require("mongoose");

const highestBidders = mongoose.Schema({
  tokenId: Number,
  collectionAddress: String,
  bidder: String,
});

module.exports = mongoose.model("highestbidders", highestBidders);
