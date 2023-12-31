pragma solidity >=0.4.22 <0.9.0;

import "./ERC20.sol";

contract BloToken {
    ERC20 erc20Contract;
    uint256 supplyLimit;
    uint256 currentSupply;
    address owner;
    event Log(string message);
    constructor() public {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
        supplyLimit = 100000;

        emit Log("Contract deployed");
    }

    // function for contract caller to exchange ETH for bLo
    function getCredit() public payable {
        // exchange rate is 0.001 ETH to 1 bLo; 1 ether gets 1000 bLo
        uint256 amt = (msg.value * 1000) / (10 ** 18);
        require(
            erc20Contract.totalSupply() + amt < supplyLimit,
            "Not enough bLo in total supply"
        );
        erc20Contract.mint(msg.sender, amt);
    }

    function checkCredit() public view returns (uint256) {
        return erc20Contract.balanceOf(msg.sender);
    }

    // function transferBloToken(address from, address to, uint256 collateral) public payable {
    //     erc20Contract.transferFrom(from, to, collateral);
    // }
    function transferBloToken(address to, uint256 value) public payable {
         erc20Contract.transfer(to, value);
    }

    function transferBloTokenBack(address from, address to, uint256 collateral) public payable {
        erc20Contract.transferFrom(from, to, collateral);
    }
}
