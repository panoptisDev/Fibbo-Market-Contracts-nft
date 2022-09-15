// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../constants");
const WRAPPED_FTM_TESTNET = "0x4F749478513C5433C02d31721f21Dc8f73A003Af";
async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const tokenRegistryAddress = await addressRegistry.tokenRegistry();

  const tokenRegistry = await ethers.getContractAt(
    "FibboTokenRegistry",
    tokenRegistryAddress
  );

  await tokenRegistry.add(WRAPPED_FTM_TESTNET);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
