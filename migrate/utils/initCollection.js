// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../../scripts/constants.js");
const mongo = require("../lib/mongo.js");
const Collection = require("../models/collection.js");

async function main(network) {
  console.log("Initliazing collection");

  const { ADDRESS_REGISTRY } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const collectionAddress = await addressRegistry.fibboCollection();

  await Collection.create({
    contractAddress: collectionAddress,
    name: "Default Collection",
    numberOfItems: 0,
    creator: "public",
  });
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
