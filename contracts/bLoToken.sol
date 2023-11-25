pragma solidity ^0.5.0;

import "./ERC20.sol";

contract bLoToken {
    ERC20 erc20Contract;
    uint256 supplyLimit;
    uint256 currentSupply;
    address owner;

    constructor() public {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
    }

    function getCredit() public payable {}

    function checkCredit() public view returns (uint256) {
        return erc20Contract.balanceOf(msg.sender);
    }
}
