const mongoose = require("mongoose");
const nftForSaleSchema = mongoose.Schema({
  collectionAddress: String,
  collectionName: String,
  name: String,
  tokenId: Number,
  image: String,
  price: Number,
  owner: String,
  forSaleAt: Date,
});

module.exports = mongoose.model("nftsForSale", nftForSaleSchema);
