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
  let proposer = signers[1];

  const communityAddres = await addressRegistry.community();

  const community = await ethers.getContractAt(
    "FibboCommunity",
    communityAddres
  );

  await community.createSuggestion(
    "Categorías de diferente tipo de arte",
    "Estaría guay que en el momento de crear el NFT se pudiera asociar una categoría, por ejemplo si la obra es arte abstracto, realista, 3D... Así se podría filtrar en la pantalla de explore.",
    ethers.utils.parseEther("100"),
    proposer.address
  );
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
