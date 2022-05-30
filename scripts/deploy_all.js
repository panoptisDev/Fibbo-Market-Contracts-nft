// to deploy locally
// run: npx hardhat node on a terminal
// then run: npx hardhat run --network localhost scripts/12_deploy_all.js

async function main(network) {
  console.log("Network is ", network.name);

  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log(`Deployer's address: `, deployerAddress);

  const { TREASURY_ADDRESS, PLATFORM_FEE } = require("./constants");

  //// Proxy deployement
  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdmin.deploy();
  await proxyAdmin.deployed();

  const PROXY_ADDRESS = proxyAdmin.address;

  console.log("ProxyAdmin deployed to: ", PROXY_ADDRESS);

  const AdminUpgradeabilityProxy = await ethers.getContractFactory(
    "AdminUpgradeabilityProxy"
  );
  ////

  //// Marketplace deployement

  const Marketplace = await ethers.getContractFactory("FibboMarketplace");
  const marketplaceImpl = await Marketplace.deploy();
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
  console.log("Marketplace Proxy Initialized");
  ////

  ///NFT Collections deployement
  const DefaultCollection = await ethers.getContractFactory("DefaultFibbo");
  const defaultCollection = await DefaultCollection.deploy(MARKETPLACE_ADDRESS);
  await defaultCollection.deployed();
  console.log("DefaultCollection deploted to: ", defaultCollection.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
