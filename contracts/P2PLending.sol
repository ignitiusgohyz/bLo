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
    // might need to map loans to borrowReq instead
    // mapping(uint256 => uint256) borrowReqToLoans;
    // mapping(uint256 => uint256) loansToBorrowReqs;

    event LoanCreated(uint loanId);
    event LoanFunded(uint loanId);
    event LoanRepaid(uint loanId);

    // this modifier should be shifted to borrowrequest
    modifier onlyActiveLoan(uint loanId) {
        require(loans[msg.sender][loanId].active, "This loan is not active");
    }

    modifier onlyBorrower(uint loanId) {
        require(loans[msg.sender][loanId].borrower == msg.sender, "Only Borrower permitted");
    }

    modifier onlyLender(uint loanId) {
        require(loans[msg.sender][loanId].lenders[msg.sender] > 0. "Only Lender permitted");
    }

    function createLoan(uint borrowRequestId) {}

    function withdrawFundsFromLoans(uint loanId) {}

    function getLoanInfo(uint loanId) external view returns (
        uint256 amount,
        uint256 interest
        uint256 duration,
        uint256 repaymentAmount,
        address borrower,
        mapping(address => uint256) lenders,
        bool repaid
    ) {
        Loan storage loan = loans[loanId];
        return ( 
            loan.amount,
            loan.interest,
            loan.duration,
            loan.repaymentAmount,
            loan.borrower,
            loan.lenders,
            loan.repaid)
    }

    // only borrower can repay their own active loans -> checked with modifier
    function repayLoan(uint loanId) external payable onlyActiveLoan(loanId) onlyBorrower(loanId) {
        // repayment amount must match the loan's repayment amount
        require(msg.value == loans[msg.sender][loanId].repaymentAmount, "Repayment amount does not match");
        // transferring of $$$$

        // change in status
        loans[msg.sender][loanId].repaid = true
        // need to look up borrow req and set it as inactive

        // emit LoanRepaid
    }

    function revokeLoan(uint loanId) {}
}
