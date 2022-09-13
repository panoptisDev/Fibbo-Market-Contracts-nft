const { getConstants } = require("../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY, FORWARDER } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const tokenRegistryAddress = await addressRegistry.tokenRegistry();

  const tokenRegistry = await ethers.getContractAt(
    "FibboTokenRegistry",
    tokenRegistryAddress
  );

  const FibboWFTM = await ethers.getContractFactory("WrappedFtm");
  const wftmToken = await FibboWFTM.deploy(FORWARDER);

  await wftmToken.deployed();

  console.log("Fibbo WFTM deployed to: ", wftmToken.address);

  await tokenRegistry.add(wftmToken.address);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
