pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract BorrowRequest {
    struct borrowRequest {
        uint256 amount;
        uint256 interest;
        uint256 collateral;
        uint256 trustScore;
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
    mapping(uint256 => borrowRequest) borrowRequests;
    mapping(address => borrowRequest[]) addressToBorrowRequests;

    modifier validBorrowRequestId(uint256 borrowRequestId) {
        require(borrowRequestId < borrowRequestCount);
        _;
    }

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
        uint8 repaymentDeadline,
        uint256 interest,
        uint8 duration,
        address borrower,
        uint256 bloTokenCollateral,
        uint256 trustScore
    ) public {
        
        uint256 newBorrowReqId = borrowRequestCount++;

        borrowRequest memory newBorrowRequest = borrowRequest(
            amount,
            interest,
            bloTokenCollateral,
            trustScore,
            repaymentDeadline,
            duration,
            borrower,
            0,
            true
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
        borrowRequest memory br = borrowRequests[borrowRequestId];
        require(
            msg.sender != br.borrower,
            "Borrower cannot fund their own borrow requests"
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

    function getBorrowRequest(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (borrowRequest memory) {
        return borrowRequests[borrowRequestId];
    }

    function getBorrower(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (address owner){
        return borrowRequests[borrowRequestId].borrower;
    }
}
