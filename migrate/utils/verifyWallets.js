// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

const { getConstants } = require("../../scripts/constants.js");
const mongo = require("../lib/mongo.js");
const Profile = require("../models/profiles.js");

async function main(network) {
  console.log("Verifying wallets");

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

  const profiles = await Profile.find();

  await Promise.all(
    profiles.map(async (profile) => {
      if (profile.verified) {
        try {
          const tx = await verification.verificateAddress(profile.wallet);
          await tx.wait();
        } catch (e) {
          console.log(profile.wallet + " is already verified");
        }
      }
    })
  );
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
