// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
const { getConstants } = require("../../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const signers = await ethers.getSigners();
  let proposer = signers[3];

  const communityAddres = await addressRegistry.community();
  const verificateAddress = await addressRegistry.verification();

  const community = await ethers.getContractAt(
    "FibboCommunity",
    communityAddres
  );

  await community.updateFibboVerification(verificateAddress);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
