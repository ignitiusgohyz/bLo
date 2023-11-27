pragma solidity ^0.6.0;

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
        uint256 amountFunded;
        // mapping(address => uint256) lenders;
        bool active;
    }

    struct LenderInfo {
        address lenderAddr;
        uint256 lentAmt;
    }

    // initializing id of borrow requests for mapping
    uint public borrowRequestCount = 0;

    // mapping borrow request id to list of LenderInfo, which contains lender address and amount he lent.
    mapping(uint256 => LenderInfo[]) public lenders;
    mapping(uint256 => BorrowRequestStruct) borrowRequests;
    mapping(address => BorrowRequestStruct[]) addressToBorrowRequests;

    /** @dev Events */
    event BorrowRequestCreated(
        uint256 amount,
        address borrower,
        uint256 interest,
        uint256 collateral,
        uint8 duration
    );

    /*should this method be in PeerToPeerLending contract? Since that contract has min and max interest rate, and 
    this method probably needs to check if the interest defined is bounded by the min and max interest rates.*/
    function createBorrowRequest(
        uint256 amount,
        uint8 fundingDeadline,
        uint8 repaymentDeadline,
        uint256 interest,
        uint8 duration,
        address borrower,
        uint256 bloTokenCollateral,
        uint256 trustScore
    ) public {
        require(duration > 0, "Loan duration must be more than 0!");
        require(bloTokenCollateral > 0, "Collateral must be more than 0!");
        require(
            repaymentDeadline > fundingDeadline,
            "Funding deadline cannot be later than repayment deadline"
        );

        uint256 newBorrowReqId = borrowRequestCount++;

        BorrowRequestStruct memory newBorrowRequest = BorrowRequestStruct(
            amount,
            interest,
            bloTokenCollateral,
            trustScore,
            fundingDeadline,
            repaymentDeadline,
            duration,
            borrower,
            0,
            false
        );

        borrowRequests[newBorrowReqId] = newBorrowRequest;

        emit BorrowRequestCreated(
            amount,
            borrower,
            interest,
            bloTokenCollateral,
            duration
        );
    }

    function fundBorrowRequest(
        uint256 borrowRequestId,
        uint256 fundingAmount
    ) external payable {
        BorrowRequestStruct memory br = borrowRequests[borrowRequestId];
        require(
            msg.sender != br.borrower,
            "Borrower cannot fund their own borrow requests"
        );
        require(
            block.timestamp <= br.fundingDeadline,
            "Funding deadline has passed for this borrow request"
        );
        require(fundingAmount < br.amountFunded, "Borrow request is already fully funded");

        payable(address(this)).transfer(fundingAmount);
        // create LoanInfo with lender address and funding amount, add to lenders mapping
        LenderInfo memory info = LenderInfo(msg.sender, fundingAmount);
        lenders[borrowRequestId].push(info);
        br.amountFunded += fundingAmount;
        // when borrow request fully funded, it should turn into loan
        if (br.amountFunded == br.amount) {
            toggleActive(borrowRequestId);
        }
    }

    // borrow request becomes active when it is actively funded i.e. turns into Loan.
    function toggleActive(uint256 borrowReqId) public {
        borrowRequests[borrowReqId].active = true;
    }
}
