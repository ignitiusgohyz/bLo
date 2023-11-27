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
        mapping(address => uint256) lenders;
        bool active;
    }

    
    // initializing id of borrow requests for mapping
    uint public borrowRequestCount = 0;

    // mapping borrow request id to list of LenderInfo, which contains lender address and amount he lent.
    
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
        uint256 fundingAmount,
        address lender
    ) external payable {
        borrowRequest storage br = borrowRequests[borrowRequestId];
        
        
        br.lenders[lender] += fundingAmount;
        payable(address(this)).transfer(fundingAmount);
        // create LoanInfo with lender address and funding amount, add to lenders mapping
      
        br.amountFunded += fundingAmount;
        // when borrow request fully funded, it should turn into loan
        if (br.amountFunded == br.amount) {
            toggleInactive(borrowRequestId);
        }
    }

    // borrow request becomes inactive when it is actively funded i.e. turns into Loan.
    function toggleInactive(uint256 borrowReqId) public {
        borrowRequests[borrowReqId].active = false;
    }

    function getBorrower(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (address owner){
        return borrowRequests[borrowRequestId].borrower;
    }

    function getIsActive(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (bool active){
        return borrowRequests[borrowRequestId].active;
    }

    function getAmountFunded(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (uint256 amountFunded){
        return borrowRequests[borrowRequestId].amountFunded;
    }

    function getAmount(uint256 borrowRequestId) public view validBorrowRequestId(borrowRequestId) returns (uint256 amount){
        return borrowRequests[borrowRequestId].amount;
    }
}
