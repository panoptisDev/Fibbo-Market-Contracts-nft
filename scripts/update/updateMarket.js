// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
// PROXY ADMIN -> 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
async function main(network) {
  console.log("Network is ", network.name);

  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdmin.attach(
    "0x5FbDB2315678afecb367f032d93F642f64180aa3"
  );

  const AdminUpgradeabilityProxy = await ethers.getContractFactory(
    "AdminUpgradeabilityProxy"
  );
  const marketplaceProxy = await AdminUpgradeabilityProxy.attach(
    "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
  );

  const Marketplace = await ethers.getContractFactory("FibboMarketplace");
  const marketplaceImpl = await Marketplace.deploy();
  await marketplaceImpl.deployed();

  console.log("FibboMarkeplace deployed to: ", marketplaceImpl.address);

  await proxyAdmin.upgrade(marketplaceProxy.address, marketplaceImpl.address);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
