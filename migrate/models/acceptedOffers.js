const mongoose = require("mongoose");

const acceptedOffersSchema = mongoose.Schema({
  creator: String,
  collectionAddress: String,
  tokenId: Number,
  payToken: String,
  price: Number,
});

module.exports = mongoose.model("acceptedoffers", acceptedOffersSchema);
