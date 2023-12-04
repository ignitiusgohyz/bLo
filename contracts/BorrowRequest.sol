pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

contract BorrowRequest {
    struct borrowRequest {
        uint256 amount;
        uint256 interest;
        uint256 collateral;
        uint256 trustScore;
        uint256 repaymentDeadLine;
        uint8 duration;
        address borrower;
        uint256 amountFunded;
        bool active;
        bool withdrawn;
    }

    struct LenderInfo {
        address lenderAddr;
        uint256 lentAmt;
    }

    // initializing id of borrow requests for mapping
    uint public borrowRequestCount = 0;

    // mapping borrow request id to list of LenderInfo, which contains lender address and amount he lent.

    mapping(uint256 => borrowRequest) borrowRequests;
    mapping(address => borrowRequest[]) addressToBorrowRequests;
    mapping(uint256 => LenderInfo[]) public lenders;

    modifier validBorrowRequestId(uint256 borrowRequestId) {
        require(borrowRequestId < borrowRequestCount, "Must be valid Borrow Request ID");
        _;
    }

    modifier onlyBorrower(uint borrowRequestId, address borrower) {
        require(
            borrowRequests[borrowRequestId].borrower == borrower,
            "Only Borrower permitted"
        );
        _;
    }

    /** @dev Events */
    event BorrowRequestCreated(
        uint256 borrowRequestId,
        uint256 amount,
        address borrower,
        uint256 interest,
        uint256 collateral,
        uint8 duration
    );

    function createBorrowRequest(
        uint256 amount,
        uint256 repaymentDeadline,
        uint256 interest,
        uint8 duration,
        address borrower,
        uint256 bloTokenCollateral,
        uint256 trustScore
    ) public returns(uint256) {
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
            true,
            false
        );

        borrowRequests[newBorrowReqId] = newBorrowRequest;

        emit BorrowRequestCreated(
            newBorrowReqId,
            amount,
            borrower,
            interest,
            bloTokenCollateral,
            duration
        );
        return newBorrowReqId;
    }

    function fundBorrowRequest(
        uint256 borrowRequestId,
        uint256 fundingAmount,
        address lender
    ) external payable {
        borrowRequest storage br = borrowRequests[borrowRequestId];

        LenderInfo memory info = LenderInfo(lender, fundingAmount);
        lenders[borrowRequestId].push(info);

        br.amountFunded += fundingAmount;
        // when borrow request fully funded, it should turn into loan
        if (br.amountFunded == br.amount) {
            toggleInactive(borrowRequestId);
        }
    }

    function withdrawFromBorrowRequest(uint borrowRequestId, address payable borrower) validBorrowRequestId(borrowRequestId) onlyBorrower(borrowRequestId, borrower) external payable {
        borrowRequests[borrowRequestId].withdrawn = true;
        borrower.transfer(borrowRequests[borrowRequestId].amount);
    }

    // borrow request becomes inactive when it is actively funded i.e. turns into Loan.
    function toggleInactive(uint256 borrowRequestId) public {
        borrowRequests[borrowRequestId].active = false;
    }

    function checkAddressExists(address _targetAddress, uint256 borrowRequestId) public view returns (bool) {
            LenderInfo[] memory lenderInfoArray = lenders[borrowRequestId];
        for (uint256 i = 0; i < lenderInfoArray.length; i++) {
            if (lenderInfoArray[i].lenderAddr == _targetAddress) {
                return true; 
            }
        }
        return false; 
    }

    function getBorrower(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (address owner)
    {
        return borrowRequests[borrowRequestId].borrower;
    }

    function getIsActive(
        uint256 borrowRequestId
    ) public view validBorrowRequestId(borrowRequestId) returns (bool active) {
        return borrowRequests[borrowRequestId].active;
    }

    function getAmountFunded(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (uint256 amountFunded)
    {
        return borrowRequests[borrowRequestId].amountFunded;
    }

    function getAmount(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (uint256 amount)
    {
        return borrowRequests[borrowRequestId].amount;
    }

    function getInterest(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (uint256 interest)
    {
        return borrowRequests[borrowRequestId].interest;
    }

    function getDuration(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (uint256 duration)
    {
        return borrowRequests[borrowRequestId].duration;
    }

    function getLenders(
        uint256 borrowRequestId
    )
        public
        view
        validBorrowRequestId(borrowRequestId)
        returns (LenderInfo[] memory lenderInfoArray)
    {
        return lenders[borrowRequestId];
    }
}
