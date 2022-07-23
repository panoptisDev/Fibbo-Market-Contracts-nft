// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const { ADDRESS_REGISTRY } = getConstants(network);

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const verificationAddress = await addressRegistry.verification();

  const verification = await ethers.getContractAt(
    "FibboVerification",
    verificationAddress
  );

  await verification.verificateAddress(
    "0x1d92D9a839e9c5D8cc02A7F87E591fF1AdA33268"
  );

  await verification.verificateAddress(
    "0x06b3cC29D74a36f15F1B2beD529Fe45E30CAaf12"
  );

  await verification.verificateAddress(
    "0x8a68B243B97C8F7E81C347418F48775D7890d0fa"
  );

  await verification.verificateAddress(
    "0x1d92D9a839e9c5D8cc02A7F87E591fF1AdA33268"
  );
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
