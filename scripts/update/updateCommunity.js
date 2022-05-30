// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

// PROXY ADMIN -> 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
async function main(network) {
  console.log("Network is ", network.name);

  const { PROXY_ADDRESS, ADDRESS_REGISTRY } = require("../constants");

  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADDRESS);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const communityAddress = await addressRegistry.community();

  const communityProxy = await ethers.getContractAt(
    "FibboCommunity",
    communityAddress
  );

  const Community = await ethers.getContractFactory("FibboCommunity");
  const communityImpl = await Community.deploy();
  await communityImpl.deployed();

  console.log("FibboMarkeplace deployed to: ", communityImpl.address);

  await proxyAdmin.upgrade(communityProxy.address, communityImpl.address);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
