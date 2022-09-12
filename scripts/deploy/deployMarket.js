const { getConstants } = require("../constants");

async function main(network) {
  console.log("Network is ", network.name);

  const {
    TREASURY_ADDRESS,
    PLATFORM_FEE,
    FORWARDER,
    PROXY_ADDRESS,
    ADDRESS_REGISTRY,
  } = getConstants(network);

  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADDRESS);

  const AdminUpgradeabilityProxy = await ethers.getContractFactory(
    "AdminUpgradeabilityProxy"
  );

  const marketAddress = await addressRegistry.marketplace();

  const Marketplace = await ethers.getContractFactory("FibboMarketplace");
  const marketplaceImpl = await Marketplace.deploy(FORWARDER);
  await marketplaceImpl.deployed();

  console.log("FibboMarkeplace deployed to: ", marketplaceImpl.address);

  const marketplaceProxy = await AdminUpgradeabilityProxy.deploy(
    marketplaceImpl.address,
    PROXY_ADDRESS,
    []
  );
  await marketplaceProxy.deployed();

  console.log("Marketplace Proxy deployed at: ", marketplaceProxy.address);
  const MARKETPLACE_ADDRESS = marketplaceProxy.address;

  const marketplace = await ethers.getContractAt(
    "FibboMarketplace",
    MARKETPLACE_ADDRESS
  );

  await marketplace.initialize(TREASURY_ADDRESS, PLATFORM_FEE);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
