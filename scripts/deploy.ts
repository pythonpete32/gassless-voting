import hre, { ethers } from "hardhat";
import EthersAdapter from '@gnosis.pm/safe-ethers-lib'
import { SafeFactory } from '@gnosis.pm/safe-core-sdk'
const { log } = console



async function main() {
  const [signer] = await ethers.getSigners();
  const FIFTY_PERCENT = 50e16.toString();
  const FIVE_PERCENT = 5e16.toString();
  const VOTE_LENGTH = (60 * 2).toString();

  let spinner: any;

  const safeFactory = await SafeFactory.create({
    ethAdapter: new EthersAdapter({
      ethers,
      signer
    })
  })

  log('creating Token')
  const Token = await ethers.getContractFactory("VotingToken");
  const token = await Token.deploy();
  log(`Token created at ${token.address}`);
  log('Waiting for 3 blocks before verifying token')
  await token.deployTransaction.wait(3);
  await hre.run("verify", {
    address: token.address,
    constructorArguments: [],
  });
  log('Module verified');

  log('deploying Safe')
  const safeSdk = await safeFactory.deploySafe({
    safeAccountConfig: {
      owners: [signer.address],
      threshold: 1,
    }
  })
  log(`Safe created at ${safeSdk.getAddress()}`);

  log('deploying Module')
  const Module = await ethers.getContractFactory("MetaVotingModule");
  const module = await Module.deploy(); // <- not initialized yet
  log(`Module created at ${module.address}`);

  log('Waiting for 3 blocks before verifying module')
  await module.deployTransaction.wait(3);
  await hre.run("verify", {
    address: module.address,
    constructorArguments: [],
  });
  log('Module verified');

  log('setting up Module')
  await module.initialize(safeSdk.getAddress(), token.address, FIFTY_PERCENT, FIVE_PERCENT, VOTE_LENGTH, "5")
  // avatar.enableModule(address(votingModule));
  // assertTrue(avatar.isModuleEnabled(address(votingModule)));
  await module.setAvatar(safeSdk.getAddress());
  await module.setTarget(safeSdk.getAddress());
  log(`avatar: ${(await module.avatar()).toString()}`)
  log(`target: ${(await module.target()).toString()}`)
  log(`Module initialized: ${(await module.initialized())}`);

  log('enabling module')
  const safeInterface = new ethers.utils.Interface(['function enableModule(address module) external'])
  const safeData = safeInterface.encodeFunctionData('enableModule', [module.address])
  const safeTransaction = await safeSdk.createTransaction({
    safeTransactionData: {
      to: safeSdk.getAddress(),
      value: '0',
      data: safeData,
    }
  })
  const executeTxResponse = await safeSdk.executeTransaction(safeTransaction)
  await executeTxResponse.transactionResponse?.wait()
  log(`Module enabled: ${(await safeSdk.isModuleEnabled(module.address))}`);

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  })