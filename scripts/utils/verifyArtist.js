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
    "0x41162C850B7176CA0A4310c33F81ffB2E0dCf99F"
  );
  await verification.verificateAddress(
    "0x985957b55D06057D0Cb59640D52C6F9f1521D3FE"
  );
  await verification.verificateAddress(
    "0x1d5318c25AcDCc270b3f92CcDB72d245836bBCc1"
  );
  await verification.verificateAddress(
    "0xDE0D0F1548B16036F6bd9cE759A32D828fF3f15d"
  );
  await verification.verificateAddress(
    "0x07d953152a282FC6F7D56Ef43e680065807EbEe7"
  );
  await verification.verificateAddress(
    "0xdfdc9D40c743BF7804EA100C132f145d64a17362"
  );
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
