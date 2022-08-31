const { getConstants } = require("../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const marketplaceAddress = await addressRegistry.marketplace();
  const DefaultCollection = await ethers.getContractFactory(
    "FibboArtTradeable"
  );
  const defaultCollection = await DefaultCollection.deploy(
    "Default Fibbo",
    "FBBO",
    marketplaceAddress
  );

  await defaultCollection.deployed();

  console.log("DefaultCollection deploted to: ", defaultCollection.address);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
