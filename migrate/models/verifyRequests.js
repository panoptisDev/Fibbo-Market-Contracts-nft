const mongoose = require("mongoose");

const verifyRequestShcema = mongoose.Schema({
  proposer: String,
  name: String,
  lastName: String,
  description: String,
  email: String,
});

module.exports = mongoose.model("verifyRequests", verifyRequestShcema);
