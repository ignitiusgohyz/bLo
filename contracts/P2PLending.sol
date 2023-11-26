pragma solidity ^0.6.0;

contract P2PLending {
    uint256 public constant MIN_LOAN_AMOUNT = 0;
    uint256 public constant MAX_LOAN_AMOUNT = 0;
    uint256 public constant MIN_INTEREST_RATE = 0;
    uint256 public constant MAX_INTEREST_RATE = 0;
    struct Loan {
        uint256 amount;
        uint256 interest;
        uint256 duration;
        uint256 repaymentAmount;
        address borrower;
        mapping(address => uint256) lenders;
        bool repaid;
    }
    mapping(address => Loan[]) public loans;
    mapping(address => uint256) public borrowerTrustScores;
    mapping(uint256 => uint256) borrowReqToCollateralAmountMapping;
    mapping(uint256 => uint256) borrowReqToLoans;
}
