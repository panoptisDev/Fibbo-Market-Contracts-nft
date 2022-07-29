const mongoose = require("mongoose");

const offerSchema = mongoose.Schema({
  creator: String,
  collectionAddress: String,
  tokenId: Number,
  payToken: String,
  price: Number,
  deadline: Number,
});

module.exports = mongoose.model("offers", offerSchema);
