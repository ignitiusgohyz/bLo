pragma solidity ^0.5.0;

contract BorrowRequest {
    struct BorrowRequestStruct {
        uint256 amount;
        uint256 interest;
        uint256 collateral;
        uint256 trustScore;
        uint8 fundingDeadline;
        uint8 repaymentDeadLine;
        uint8 duration;
        address borrower;
        mapping(address => uint256) lenders;
        bool active;
    }

    mapping(uint256 => BorrowRequestStruct) borrowRequests;
    mapping(address => BorrowRequestStruct[]) addressToBorrowRequests;
}
