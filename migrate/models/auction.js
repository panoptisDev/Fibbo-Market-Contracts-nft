const mongoose = require("mongoose");

const auctionSchema = mongoose.Schema({
  collectionAddress: String,
  tokenId: Number,
  payToken: String,
  reservePrice: Number,
  buyNowPrice: Number,
  startTime: Number,
  endTime: Number,
});

module.exports = mongoose.model("auctions", auctionSchema);
