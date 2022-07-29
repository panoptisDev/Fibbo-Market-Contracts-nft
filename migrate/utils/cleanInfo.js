// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../../scripts/constants.js");
const mongo = require("../lib/mongo.js");
const Collection = require("../models/collection.js");
const Nft = require("../models/nft.js");
const NftForSale = require("../models/nftForSale.js");
const Events = require("../models/events.js");
const Suggestion = require("../models/suggestions.js");
const VerifyRequests = require("../models/verifyRequests.js");
const Offers = require("../models/offers.js");
const Auctions = require("../models/auction.js");
const profiles = require("../models/profiles.js");

async function main(network) {
  console.log("Cleaning DB info");

  //Delete collections
  await Collection.deleteMany({});
  await profiles.deleteMany({});

  //Delete Nfts
  await Nft.deleteMany({});
  await NftForSale.deleteMany({});

  //Delete events
  await Events.deleteMany({});

  //Delete Suggestions
  await Suggestion.deleteMany({});

  //Delete verifyRequests
  await VerifyRequests.deleteMany({});

  //Delete Offers
  await Offers.deleteMany({});

  //Delete Auctions
  await Auctions.deleteMany({});
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
