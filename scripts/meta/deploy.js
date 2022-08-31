const {
  DefenderRelayProvider,
  DefenderRelaySigner,
} = require("defender-relay-client/lib/ethers");
const { ethers } = require("hardhat");
const { writeFileSync } = require("fs");
const { getConstants } = require("../constants");

async function main() {
  require("dotenv").config();
  const MANNAGER = "0xBcBE0c2F3aB715340DECf7b444577935599b0F8f";
  const { PROXY_ADDRESS, ADDRESS_REGISTRY, PLATFORM_FEE } =
    getConstants(network);

  const credentials = {
    apiKey: process.env.RELAYER_API_KEY,
    apiSecret: process.env.RELAYER_API_SECRET,
  };
  const provider = new DefenderRelayProvider(credentials);
  const relaySigner = new DefenderRelaySigner(credentials, provider, {
    speed: "fast",
  });

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  const marketAddress = await addressRegistry.marketplace();
  const verification = await addressRegistry.verification();

  const Forwarder = await ethers.getContractFactory("MinimalForwarder");
  const forwarder = await Forwarder.connect(relaySigner)
    .deploy()
    .then((f) => f.deployed());

  const Factory = await ethers.getContractFactory("FibboArtFactory");
  const factory = await Factory.connect(relaySigner)
    .deploy(marketAddress, verification, MANNAGER, forwarder.address)
    .then((f) => f.deployed());

  writeFileSync(
    "deploy.json",
    JSON.stringify(
      {
        MinimalForwarder: forwarder.address,
        Factory: factory.address,
      },
      null,
      2
    )
  );

  await addressRegistry.updateFactory(factory.address);

  console.log(
    `MinimalForwarder: ${forwarder.address}\Factory: ${factory.address}`
  );
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
