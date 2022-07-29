const mongoose = require("mongoose");

const nftSchema = mongoose.Schema({
  collectionAddress: String,
  name: String,
  description: String,
  owner: String,
  creator: String,
  tokenId: Number,
  image: String,
  royalty: Number,
  createdAt: Date,
  additionalContent: String,
});

module.exports = mongoose.model("nfts", nftSchema);
