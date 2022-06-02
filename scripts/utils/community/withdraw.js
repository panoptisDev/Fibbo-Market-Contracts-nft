// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
const { getConstants } = require("../../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = getConstants(network);
  const provider = ethers.provider;
  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const signers = await ethers.getSigners();
  const owner = signers[0];
  let proposer1 = signers[1];

  const communityAddres = await addressRegistry.community();

  const community = await ethers.getContractAt(
    "FibboCommunity",
    communityAddres
  );

  let contractBalance = await provider.getBalance(communityAddres);
  let ownerBalance = await provider.getBalance(owner.address);
  let proposer1Balance = await provider.getBalance(proposer1.address);
  console.log("Contract Balance = ", contractBalance);
  console.log("Owner Balance = ", ownerBalance);
  console.log("Proposer Balance = ", proposer1Balance);

  await community.withdrawFromSuggestion(1, 1);

  console.log("Later when withdrawed =========");
  contractBalance = await provider.getBalance(communityAddres);
  ownerBalance = await provider.getBalance(owner.address);
  proposer1Balance = await provider.getBalance(proposer1.address);
  console.log("* Owner Balance = ", ownerBalance);
  console.log("* Owner Balance = ", contractBalance);
  console.log("* Proposer Balance = ", proposer1Balance);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
