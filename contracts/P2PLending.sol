pragma solidity ^0.6.0;
import "./BorrowRequest.sol";

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
        bool repaid;
    }

    struct LenderInfo {
        address lenderAddr;
        uint256 lentAmt;
    }

    BorrowRequest brContract;
    uint public loanCount = 0;

    mapping(uint256 => LenderInfo[]) public lenders;
    mapping(address => Loan[]) public addressToLoans;
    mapping(uint => Loan) public loans;
    mapping(address => uint256) public borrowerTrustScores;
    mapping(uint256 => uint256) borrowReqToCollateralAmountMapping;
    mapping(uint256 => uint256) loanToBorrowReqMapping;

    event LoanCreated(uint loanId);
    event LoanFunded(uint loanId);
    event LoanRepaid(uint loanId);

    // this modifier should be shifted to borrowrequest
    modifier onlyUnrepaidLoan(uint loanId) {
        require(
            !addressToLoans[msg.sender][loanId].repaid,
            "This loan has not been repaid"
        );
        _;
    }

    modifier onlyBorrower(uint loanId) {
        require(
            addressToLoans[msg.sender][loanId].borrower == msg.sender,
            "Only Borrower permitted"
        );
        _;
    }

    modifier onlyLender(uint loanId) {
        LenderInfo[] storage lenderInfoArray = lenders[loanId];

        bool exists = false;
        for (uint256 i = 0; i < lenderInfoArray.length; i++) {
            if (lenderInfoArray[i].lenderAddr == msg.sender) {
                exists = true;
                break;
            }
        }
        require(exists, "Only Lender permitted");
        _;
    }

    function createLoan(uint borrowRequestId) public {
        // get BorrowRequestStruct instance from BorrowRequest contract using getter method defined in BorrowRequest
        // use instance variables to create Loan
        // map the loan id to the loan, increment loan count
    }

    function withdrawFundsFromLoans(uint loanId) public {}

    function getLoanInfo(
        uint loanId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 interest,
            uint256 duration,
            uint256 repaymentAmount,
            address borrower,
            bool repaid
        )
    {
        Loan storage loan = loans[loanId];
        return (
            loan.amount,
            loan.interest,
            loan.duration,
            loan.repaymentAmount,
            loan.borrower,
            loan.repaid
        );
    }

    // only borrower can repay their own unrepaid loans -> checked with modifier
    function repayLoan(
        uint loanId
    ) external payable onlyUnrepaidLoan(loanId) onlyBorrower(loanId) {
        // repayment amount must match the loan's repayment amount
        require(
            msg.value == addressToLoans[msg.sender][loanId].repaymentAmount,
            "Repayment amount does not match"
        );
        // transferring of $$$$ to individual lenders
        LenderInfo[] storage lenderInfoArray = lenders[loanId];
        for (uint256 i = 0; i < lenderInfoArray.length; i++) {
            payable(lenderInfoArray[i].lenderAddr).transfer(
                lenderInfoArray[i].lentAmt * (1 + loans[loanId].interest)
            );
        }
        // transferring of collateral to the borrower
        uint256 collateral = borrowReqToCollateralAmountMapping[
            loanToBorrowReqMapping[loanId]
        ];
        payable(msg.sender).transfer(collateral);
        // change in status
        addressToLoans[msg.sender][loanId].repaid = true;
        // need to look up borrow req and set it as inactive

        // emit LoanRepaid
        emit LoanRepaid(loanId);
    }

    function revokeLoan(uint loanId) public {}
}
