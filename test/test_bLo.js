const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");
const BigNumber = require('bignumber.js');
const oneEth = new BigNumber(1000000000000000000); // 1 eth

var BloToken = artifacts.require("../contracts/BloToken.sol");
var BorrowRequest = artifacts.require("../contracts/BorrowRequest.sol");
var P2PLending = artifacts.require("../contracts/P2PLending.sol");

contract ('P2PLending', function(accounts){
    before( async() => {
        bloTokenInstance = await BloToken.deployed();
        borrowRequestInstance = await DiceMarket.deployed();
        p2pLendingInstance = await P2PLending.deployed();
    });
    console.log("Testing P2P Lending contract");


})

