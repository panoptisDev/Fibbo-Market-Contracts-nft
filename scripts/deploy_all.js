// to deploy locally
// run: npx hardhat node on a terminal
// then run: npx hardhat run --network localhost scripts/12_deploy_all.js

const WRAPPED_FTM_MAINNET = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83";
const WRAPPED_FTM_TESTNET = "0xf1277d1ed8ad466beddf92ef448a132661956621";

const { getConstants } = require("./constants");

async function main(network) {
  console.log("Network is ", network.name);

  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log(`Deployer's address: `, deployerAddress);

  const { TREASURY_ADDRESS, PLATFORM_FEE } = getConstants(network);

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

  //// Auction deployement
  const Auction = await ethers.getContractFactory("FibboAuction");
  const auctionIml = await Auction.deploy();
  await auctionIml.deployed();

  console.log("FibboMarkeplace deployed to: ", auctionIml.address);

  const auctionProxy = await AdminUpgradeabilityProxy.deploy(
    auctionIml.address,
    PROXY_ADDRESS,
    []
  );
  await auctionProxy.deployed();

  console.log("Auction Proxy deployed at: ", auctionProxy.address);
  const AUCTION_ADDRESS = auctionProxy.address;

  const auction = await ethers.getContractAt("FibboAuction", AUCTION_ADDRESS);

  await auction.initialize(TREASURY_ADDRESS, PLATFORM_FEE);
  console.log("Auction Proxy Initialized");
  ////

  //// Factory deployement
  const Factory = await ethers.getContractFactory("FibboArtFactory");
  const factoryImpl = await Factory.deploy();
  await factoryImpl.deployed();

  console.log("FibboArtFactory deployed to: ", factoryImpl.address);

  const factoryProxy = await AdminUpgradeabilityProxy.deploy(
    factoryImpl.address,
    PROXY_ADDRESS,
    []
  );
  await factoryProxy.deployed();

  console.log("FibboArtFactory Proxy deployed at: ", factoryProxy.address);
  const FACTORY_ADDRESS = factoryProxy.address;

  const factory = await ethers.getContractAt(
    "FibboArtFactory",
    FACTORY_ADDRESS
  );

  await factory.initialize(MARKETPLACE_ADDRESS);
  console.log("FibboArtFactory Proxy Initialized");
  ////

  //// TokenRegistry Deployement
  const TokenRegistry = await ethers.getContractFactory("FibboTokenRegistry");
  const tokenRegistry = await TokenRegistry.deploy();

  await tokenRegistry.deployed();

  console.log("TokenRegistry deployed to", tokenRegistry.address);
  ////

  //// Community deployement
  const Community = await ethers.getContractFactory("FibboCommunity");
  const comunityImpl = await Community.deploy();
  await comunityImpl.deployed();

  console.log("FibboCommunity deployed to: ", comunityImpl.address);

  const communityProxy = await AdminUpgradeabilityProxy.deploy(
    comunityImpl.address,
    PROXY_ADDRESS,
    []
  );
  await communityProxy.deployed();

  console.log("Community Proxy deployed at: ", communityProxy.address);
  const COMMUNITY_ADDRESS = communityProxy.address;

  const community = await ethers.getContractAt(
    "FibboCommunity",
    COMMUNITY_ADDRESS
  );

  await community.initialize(PLATFORM_FEE);

  console.log("Community proxy initalized");

  ////

  //// Verification Deployement
  const Verification = await ethers.getContractFactory("FibboVerification");
  const verificationImpl = await Verification.deploy();
  await verificationImpl.deployed();

  console.log("Verification deployed to: ", verificationImpl.address);

  const verificationProxy = await AdminUpgradeabilityProxy.deploy(
    verificationImpl.address,
    PROXY_ADDRESS,
    []
  );
  await verificationProxy.deployed();

  console.log("Verification Proxy deployed at: ", verificationProxy.address);
  const VERIFICATION_ADDRESS = verificationProxy.address;

  const verification = await ethers.getContractAt(
    "FibboVerification",
    VERIFICATION_ADDRESS
  );

  await verification.initialize();

  console.log("Verification proxy initalized");
  ////

  //// NFT Collections deployement
  const DefaultCollection = await ethers.getContractFactory(
    "FibboArtTradeable"
  );
  const defaultCollection = await DefaultCollection.deploy(
    "Default Fibbo",
    "FBBO",
    MARKETPLACE_ADDRESS,
    VERIFICATION_ADDRESS,
    deployerAddress
  );
  await defaultCollection.deployed();
  console.log("DefaultCollection deploted to: ", defaultCollection.address);
  ////

  //// AddressRegistry deployement
  const AddressRegistry = await ethers.getContractFactory(
    "FibboAddressRegistry"
  );
  const addressRegistryImpl = await AddressRegistry.deploy();
  await addressRegistryImpl.deployed();

  console.log("AddressRegistry deployed to: ", addressRegistryImpl.address);

  const addressRegistryProxy = await AdminUpgradeabilityProxy.deploy(
    addressRegistryImpl.address,
    PROXY_ADDRESS,
    []
  );
  await addressRegistryProxy.deployed();

  console.log(
    "AddressRegistry Proxy deployed at: ",
    addressRegistryProxy.address
  );
  const ADDRESS_REGISTRY = addressRegistryProxy.address;

  const addressRegistry = await ethers.getContractAt(
    "FibboAddressRegistry",
    ADDRESS_REGISTRY
  );

  await addressRegistry.initialize();

  console.log("AddressRegistry proxy initalized");

  await defaultCollection.updateFibboVerification(VERIFICATION_ADDRESS);
  await marketplace.updateFibboVerification(VERIFICATION_ADDRESS);
  await community.updateFibboVerification(VERIFICATION_ADDRESS);
  await factory.updateFibboVerification(VERIFICATION_ADDRESS);

  await marketplace.updateAddressRegistry(ADDRESS_REGISTRY);
  await auction.updateAddressRegistry(ADDRESS_REGISTRY);

  await addressRegistry.updateFibboCollection(defaultCollection.address);
  await addressRegistry.updateMarketplace(marketplace.address);
  await addressRegistry.updateAuction(auction.address);
  await addressRegistry.updateCommunity(community.address);
  await addressRegistry.updateVerification(verification.address);
  await addressRegistry.updateTokenRegistry(tokenRegistry.address);
  await addressRegistry.updateFactory(factory.address);

  await tokenRegistry.add(WRAPPED_FTM_TESTNET);

  console.log("AddressRegistry has been filled");
  ////
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
