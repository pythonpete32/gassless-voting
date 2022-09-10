- [x] create basic voting app
- [x] import biconomy stuff into it
- [x] make it into a gnosis module
- [ ] make deployment script
- [ ] make foundry tests
https://github.com/safe-global/safe-contracts/blob/da66b45ec87d2fb6da7dfd837b29eacdb9a604c5/test/factory/ProxyFactory.spec.ts


singleton = '0x3E5c63644E683549055b9Be8653de26E0B4CD36E'
factory = '0xa6b71e26c5e0845f74c812102ca7114b6a896ab2'


encode setup on the singletton



1. generate init code by calling encodeFunctionData on the init function of the singleton 
```js
    /// @dev Setup function sets initial storage of contract.
    /// @param _owners List of Safe owners.
    /// @param _threshold Number of required confirmations for a Safe transaction.
    /// @param to Contract address for optional delegate call.
    /// @param data Data payload for optional delegate call.
    /// @param fallbackHandler Handler for fallback calls to this contract
    /// @param paymentToken Token that should be used for the payment (0 is ETH)
    /// @param payment Value that should be paid
    /// @param paymentReceiver Adddress that should receive the payment (or 0 if tx.origin)
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
        ```

2. calculate proxy address ?
3. 


```ts
import { ethers, Contract } from "ethers"

export const calculateProxyAddress = async (factory: Contract, singleton: string, inititalizer: string, nonce: number | string) => {
    const deploymentCode = ethers.utils.solidityPack(["bytes", "uint256"], [await factory.proxyCreationCode(), singleton])
    const salt = ethers.utils.solidityKeccak256(
        ["bytes32", "uint256"],
        [ethers.utils.solidityKeccak256(["bytes"], [inititalizer]), nonce]
    )
    return ethers.utils.getCreate2Address(factory.address, salt, ethers.utils.keccak256(deploymentCode))
}

export const calculateProxyAddressWithCallback = async (factory: Contract, singleton: string, inititalizer: string, nonce: number | string, callback: string) => {
    const saltNonceWithCallback = ethers.utils.solidityKeccak256(
        ["uint256", "address"],
        [nonce, callback]
    )
    return calculateProxyAddress(factory, singleton, inititalizer, saltNonceWithCallback)
}
```