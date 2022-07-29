const mongoose = require("mongoose");

const collectionSchema = mongoose.Schema({
  contractAddress: String,
  name: String,
  numberOfItems: Number,
});

module.exports = mongoose.model("collections", collectionSchema);
