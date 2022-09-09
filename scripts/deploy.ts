import hre from "hardhat";

async function main() {

  const VotingToken = await hre.ethers.getContractFactory("VotingToken");
  const votingToken = await VotingToken.deploy();
  await votingToken.deployTransaction.wait(5);

  console.log("VotingToken deployed to:", votingToken.address);
  await hre.run("verify", {
    address: votingToken.address,
    constructorArguments: [],
  });

  const DAO = await hre.ethers.getContractFactory("DAO");
  const dao = await DAO.deploy(votingToken.address, '0x0000000000000000000000000000000000000000');
  await dao.deployTransaction.wait(5);

  console.log("DAO deployed to:", dao.address);
  await hre.run("verify", {
    address: dao.address,
    constructorArguments: [],
  });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
