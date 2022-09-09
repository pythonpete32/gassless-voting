# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean remove install update build 


# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "⚒️ modules"

# Install the Modules
install :; 
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts
	forge install transmissions11/solmate
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable


# Update Dependencies
update:; forge update

# Builds
build  :; forge clean && forge build --optimize --optimizer-runs 1000000

# add deploy script here
deploy_goerli:; forge script script/DeployGoerli.s.sol:DeployGoerli --rpc-url $(GOERLI_RPC_URL)  --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_KEY) -vvvvv

