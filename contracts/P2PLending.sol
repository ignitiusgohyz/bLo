pragma solidity >=0.4.22 <0.9.0;
import "./BorrowRequest.sol";
import "./BloToken.sol";
pragma experimental ABIEncoderV2;

contract P2PLending {
    uint256 public constant MIN_LOAN_AMOUNT = 100000000000000000;
    uint256 public constant MAX_LOAN_AMOUNT = 10000000000000000000;
    uint256 public constant MIN_INTEREST_RATE = 5;
    uint256 public constant MAX_INTEREST_RATE = 20;
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

    BloToken bloTokenContract;
    BorrowRequest borrowRequestContract;
    uint public loanCount = 0;

    mapping(uint256 => LenderInfo[]) public lenders;
    mapping(uint => Loan) public loans;
    mapping(address => uint256) public borrowerTrustScores;
    mapping(uint256 => uint256) borrowReqToCollateralAmountMapping;
    mapping(uint256 => uint256) loanToBorrowReqMapping;

    event LoanCreated(uint loanId);
    event LoanFunded(uint loanId);
    event LoanRepaid(uint loanId);

    // this modifier should be shifted to borrowrequest
    modifier onlyUnrepaidLoan(uint loanId) {
        require(!loans[loanId].repaid, "This loan has not been repaid");
        _;
    }

    modifier onlyBorrower(uint loanId) {
        require(
            loans[loanId].borrower == msg.sender,
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

    modifier notBorrower(uint borrowRequestId) {
        require(
            borrowRequestContract.getBorrower(borrowRequestId) != msg.sender,
            "You cannot fund your own request"
        );
        _;
    }

    modifier isActiveBorrowRequest(uint borrowRequestId) {
        require(
            borrowRequestContract.getIsActive(borrowRequestId),
            "Borrow Request is not active"
        );
        _;
    }

    modifier validLoanId(uint256 loanId) {
        require(loanId < loanCount, "Must be valid Loan ID");
        _;
    }

    constructor(BloToken bloTokenAddr, BorrowRequest borrowRequestAddr) public {
        bloTokenContract = bloTokenAddr;
        borrowRequestContract = borrowRequestAddr;
    }

    function createNewBorrowRequest(
        uint256 amount,
        uint256 repaymentDeadline,
        uint256 interest,
        uint8 duration,
        uint256 bloTokenCollateral
    ) public {
        validateLoanParams(
            amount,
            interest,
            duration,
            bloTokenCollateral,
            repaymentDeadline
        );
        if (borrowerTrustScores[msg.sender] == 0) {
            borrowerTrustScores[msg.sender] = 50; //set default
        }
        uint256 borrowRequestId = borrowRequestContract.createBorrowRequest(
            amount,
            repaymentDeadline,
            interest,
            duration,
            msg.sender,
            bloTokenCollateral,
            borrowerTrustScores[msg.sender]
        );
        // update borrowReqToCollateralAmountMapping
        borrowReqToCollateralAmountMapping[
            borrowRequestId
        ] = bloTokenCollateral;

        //send collateral to address
        bloTokenContract.transferBloToken(address(this), bloTokenCollateral);
    }

    function fundBorrowRequest(
        uint256 borrowRequestId
    )
        public
        payable
        notBorrower(borrowRequestId)
        isActiveBorrowRequest(borrowRequestId)
    {
        uint256 amount = msg.value;
        uint256 amountFunded = borrowRequestContract.getAmountFunded(
            borrowRequestId
        );
        uint256 borrowRequestAmount = borrowRequestContract.getAmount(
            borrowRequestId
        );

        if (amount + amountFunded >= borrowRequestAmount) {
            createLoan(borrowRequestId);

            uint256 leftover = borrowRequestAmount - (amount + amountFunded);
            if (leftover > 0) {
                address payable lender = payable(msg.sender);
                lender.transfer(leftover);
            }
            borrowRequestContract.fundBorrowRequest(
                borrowRequestId,
                amount - leftover,
                msg.sender
            );
            // transfer funds to borrower
            address payable receipient = payable(
                address(borrowRequestContract.getBorrower(borrowRequestId))
            );
            receipient.transfer(amount - leftover);
        } else {
            borrowRequestContract.fundBorrowRequest(
                borrowRequestId,
                amount,
                msg.sender
            );
            // transfer funds to borrower
            address payable receipient = payable(
                address(borrowRequestContract.getBorrower(borrowRequestId))
            );
            receipient.transfer(amount);
        }
    }

    function createLoan(uint borrowRequestId) public {
        uint256 interest = borrowRequestContract.getInterest(borrowRequestId);
        uint256 duration = borrowRequestContract.getDuration(borrowRequestId);
        uint256 amount = borrowRequestContract.getAmount(borrowRequestId);
        address borrower = borrowRequestContract.getBorrower(borrowRequestId);

        uint256 repaymentAmount = amount * (1 + interest / 100);

        Loan memory newLoan = Loan(
            amount,
            interest,
            duration,
            repaymentAmount,
            borrower,
            false
        );
        loanCount++;
        loans[loanCount] = newLoan;
        //update loanToBorrowReqMapping
        loanToBorrowReqMapping[loanCount] = borrowRequestId;
        //set borrowreq as inactive
        borrowRequestContract.toggleInactive(borrowRequestId);

        emit LoanCreated(loanCount);
    }

    function withdrawFundsFromLoans(
        uint loanId
    ) public validLoanId(loanId) onlyBorrower(loanId) {
        uint256 borrowRequestId = loanToBorrowReqMapping[loanId];
        address payable borrower = payable(msg.sender);
        borrowRequestContract.withdrawFromBorrowRequest(
            borrowRequestId,
            borrower
        );
    }

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
            loans[loanId].repaymentAmount == msg.value,
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
        bloTokenContract.transferBloTokenBack(
            address(this),
            msg.sender,
            collateral
        );
        // change in status
        loans[loanId].repaid = true;
        // need to look up borrow req and set it as inactive

        // emit LoanRepaid
        emit LoanRepaid(loanId);
    }

    function revokeBorrowRequestId(uint borrowRequestId) public {
        require(
            borrowRequestContract.getIsActive(borrowRequestId),
            "Can only revoke active loans"
        );
        require(
            borrowRequestContract.getBorrower(borrowRequestId) == msg.sender,
            "Only borrower permitted to revoke borrow request."
        );
        // iterate through lenders and send them back their money
        BorrowRequest.LenderInfo[]
            memory lenderInfoArray = borrowRequestContract.getLenders(
                borrowRequestId
            );
        for (uint256 i = 0; i < lenderInfoArray.length; i++) {
            payable(lenderInfoArray[i].lenderAddr).transfer(
                lenderInfoArray[i].lentAmt
            );
        }
        // collateral return back
        uint256 collateral = borrowReqToCollateralAmountMapping[
            borrowRequestId
        ];
        payable(msg.sender).transfer(collateral);
    }

    function validateLoanParams(
        uint256 amount,
        uint256 interest,
        uint256 duration,
        uint256 bloTokenCollateral,
        uint256 repaymentDeadline
    ) internal view {
        require(
            amount < MAX_LOAN_AMOUNT && amount > MIN_LOAN_AMOUNT,
            "Invalid loan amount"
        );
        require(
            interest < MAX_INTEREST_RATE && interest > MIN_INTEREST_RATE,
            "Invalid interest rate"
        );
        require(duration > 0, "Loan duration must be more than 0!");
        require(bloTokenCollateral > 0, "Collateral must be more than 0!");
        require(
            repaymentDeadline > block.timestamp,
            "Repayment date must be in the future"
        );
    }
}
