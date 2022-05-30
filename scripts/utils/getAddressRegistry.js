// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = require("../constants");

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const marketAddress = await addressRegistry.marketplace();
  const communityAddress = await addressRegistry.community();

  console.log("Marketplace deployed at: ", marketAddress);
  console.log("Community deployed at: ", communityAddress);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
