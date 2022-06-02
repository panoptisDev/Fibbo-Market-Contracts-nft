// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../constants");

// PROXY ADMIN -> 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
async function main(network) {
  console.log("Network is ", network.name);

  const { PROXY_ADDRESS, ADDRESS_REGISTRY } = getConstants(network);

  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADDRESS);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const verificationAddress = await addressRegistry.verification();

  const verificationProxy = await ethers.getContractAt(
    "FibboVerification",
    verificationAddress
  );

  const Verification = await ethers.getContractFactory("FibboVerification");
  const verificationImpl = await Verification.deploy();
  await verificationImpl.deployed();

  console.log("FibboVerification deployed to: ", verificationImpl.address);

  await proxyAdmin.upgrade(verificationProxy.address, verificationImpl.address);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
