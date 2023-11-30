// describe how we want the blockchain to work
const ERC20 = artifacts.require("ERC20");
const BloToken = artifacts.require("BloToken");
const BorrowRequest = artifacts.require("BorrowRequest");
const P2PLending = artifacts.require("P2PLending")
const BigNumber = require('bignumber.js');
const commissionFee = new BigNumber(1000000000000000000); // 1 eth

module.exports = async (deployer, network, accounts) => {
    // Deploy ERC20, BloToken, BorrowRequest, and other contracts as needed
    await deployer.deploy(ERC20);
    await deployer.deploy(BloToken);
    await deployer.deploy(BorrowRequest);
    await deployer.deploy(P2PLending, ERC20.address, BloToken.address, BorrowRequest.address, commissionFee);

    
};