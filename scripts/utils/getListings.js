// MARKET -> 0x0165878A594ca255338adfa4d48449f69242Eb8F
// PROXY -> 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853

async function main(network) {
  console.log("Network is ", network.name);

  const Marketplace = await ethers.getContractFactory("FibboMarketplace");

  const marketplace = await Marketplace.attach(
    "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
  );

  console.log("Marketplace address : ", marketplace.address);

  const minters = await marketplace.listings(
    "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
    1,
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  );

  console.log(minters);
}

main(network)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
