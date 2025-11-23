const { ethers } = require("hardhat");

async function main() {
  const TokenVerseHub = await ethers.getContractFactory("TokenVerseHub");
  const tokenVerseHub = await TokenVerseHub.deploy();

  await tokenVerseHub.deployed();

  console.log("TokenVerseHub contract deployed to:", tokenVerseHub.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
