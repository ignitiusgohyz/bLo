const _deploy_contracts = require("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");
const BigNumber = require("bignumber.js");
const oneEth = new BigNumber(1000000000000000000); // 1 eth

var BloToken = artifacts.require("../contracts/BloToken.sol");
var BorrowRequest = artifacts.require("../contracts/BorrowRequest.sol");
var P2PLending = artifacts.require("../contracts/P2PLending.sol");

contract("BorrowRequest", (accounts) => {
  before(async () => {
    bloTokenInstance = await BloToken.deployed();
    borrowRequestInstance = await BorrowRequest.deployed();
  });
  console.log("Testing BorrowRequest contract");

  it("test create a borrow request", async () => {
    const amount = web3.utils.toWei("1", "ether");
    const currentTimestamp = Math.floor(new Date().getTime() / 1000);
    const repaymentDeadline = currentTimestamp + 24 * 60 * 60;
    const interest = 10;
    const duration = 30;
    const bloTokenCollateral = 50;
    const initialCount = await borrowRequestInstance.borrowRequestCount();
    const result = await borrowRequestInstance.createBorrowRequest(
      amount,
      repaymentDeadline,
      interest,
      duration,
      accounts[1],
      bloTokenCollateral,
      50
    );
    const newCount = await borrowRequestInstance.borrowRequestCount();

    // check BorrowRequestCreated event is emitted
    truffleAssert.eventEmitted(result, "BorrowRequestCreated");
    // check borrow request count incremented by 1
    assert.equal(
      newCount.toNumber(),
      initialCount.toNumber() + 1,
      "Borrow request not created"
    );
  });
});

contract("P2PLending", function (accounts) {
  before(async () => {
    bloTokenInstance = await BloToken.deployed();
    borrowRequestInstance = await BorrowRequest.deployed();
    p2pLendingInstance = await P2PLending.deployed();
  });
  console.log("Testing P2P Lending contract");

  it("should allow users to exchange ETH for bLo tokens", async () => {
    const bloTokenInstance = await BloToken.deployed();

    // Account to test with
    const userAccount = accounts[1];

    // Initial bLo balance
    const initialBloBalance = await bloTokenInstance.checkCredit({
      from: userAccount,
    });

    // Amount to send in ETH (adjust as needed)
    const ethAmount = web3.utils.toWei("1", "ether");

    // Send ETH and get bLo tokens
    await bloTokenInstance.getCredit({ from: userAccount, value: ethAmount });

    // Check the updated bLo balance
    const updatedBloBalance = await bloTokenInstance.checkCredit({
      from: userAccount,
    });

    // Ensure the balance has increased by the expected amount
    assert.equal(
      updatedBloBalance.toNumber(),
      initialBloBalance.toNumber() + 1000, // Assuming 1 ETH = 1000 bLo
      "Exchange did not result in the expected bLo balance"
    );
  });

  it("should create a borrow request and send collateral to the contract", async () => {
    // Account to test with
    const borrowerAccount = accounts[1];
    console.log("BORROWER ACCOUNT:" + borrowerAccount);

    // Initial borrow request count
    const initialBorrowRequestCount =
      await borrowRequestInstance.borrowRequestCount();

    // Initial collateral balance of the contract
    const initialContractCollateral = await bloTokenInstance.checkCredit({
      from: p2pLendingInstance.address,
    });

    const amount = web3.utils.toWei("1", "ether");

    const currentTimestamp = Math.floor(new Date().getTime() / 1000);
    const repaymentDeadline = currentTimestamp + 24 * 60 * 60;

    const interest = 10;
    const duration = 30;
    const bloTokenCollateral = 50;

    // Call createBorrowRequest
    await p2pLendingInstance.createNewBorrowRequest(
        amount,
        repaymentDeadline,
        interest,
        duration,
        bloTokenCollateral,
        { from: borrowerAccount });

    // Verify that a new borrow request is created
    const newBorrowRequestCount =
      await borrowRequestInstance.borrowRequestCount();
    assert.equal(
      newBorrowRequestCount.toNumber(),
      initialBorrowRequestCount.toNumber() + 1,
      "Borrow request not created"
    );

    // Verify that collateral is sent to the contract
    const newContractCollateral = await bloTokenInstance.checkCredit({
      from: p2pLendingInstance.address,
    });
    assert.equal(
      newContractCollateral.toNumber(),
      initialContractCollateral.toNumber() + bloTokenCollateral,
      "Collateral not sent to the contract"
    );
  });

  it("Lender can fund active borrow request", async () => {
    const lenderAccount = accounts[4];
    const amountToFund = web3.utils.toWei("0.5", "ether");
    const initialBalance = await web3.eth.getBalance(borrowRequestInstance.address);
    console.log(BigNumber(initialBalance));
    await p2pLendingInstance.fundBorrowRequest(0, {
      from: lenderAccount,
      value: amountToFund,
    });
    
    // check that lender got added into lenders mapping of the specific borrow request
    // get LenderInfo[] of borrow request by borrow request id
    const exists = await borrowRequestInstance.checkAddressExists(
      lenderAccount,
      0
    );
    const initialCount = await p2pLendingInstance.loanCount();
    const secondLenderAccount = accounts[5];
    const secondAmountToFund = web3.utils.toWei("0.5", "ether");
    const secondFunding = await p2pLendingInstance.fundBorrowRequest(0, {
      from: secondLenderAccount,
      value: secondAmountToFund,
    });
    const secondLenderExists = await borrowRequestInstance.checkAddressExists(
      secondLenderAccount,
      0
    );
    assert.equal(
      exists,
      true,
      "Lender 1 not in lenders list, funding did not execute correctly"
    );
    assert.equal(
      secondLenderExists,
      true,
      "Lender 2 not in lenders list, funding did not execute correctly"
    );
    truffleAssert.eventEmitted(secondFunding, "LoanCreated");
    const newCount = await p2pLendingInstance.loanCount();
    console.log(newCount.toNumber());
    assert.equal(
      newCount.toNumber(),
      initialCount.toNumber() + 1,
      "Loan not created"
    );
  });

  it("Borrower can withdraw from the loan", async() => {
    const borrowerAccount = accounts[1];
    

    const borrowedAmt = await borrowRequestInstance.getAmount(0);
    console.log(BigNumber(borrowedAmt));


    const initialBalance = new BigNumber(await web3.eth.getBalance(borrowerAccount));
    await p2pLendingInstance.withdrawFundsFromLoans(0, {from: borrowerAccount});

 
    const finalBalance = new BigNumber(await web3.eth.getBalance(borrowerAccount));
    const withdrawn = await borrowRequestInstance.getWithdrawn(0);
    const expectedFinalBalance = initialBalance.plus(new BigNumber(borrowedAmt));

    // Allow for a small variance due to gas fees or other factors
    const variance = new BigNumber(web3.utils.toWei("0.01", "ether")); // Adjust as needed
    const isWithinVariance = finalBalance.isGreaterThanOrEqualTo(expectedFinalBalance.minus(variance)) &&
                           finalBalance.isLessThanOrEqualTo(expectedFinalBalance.plus(variance));

    assert.equal(isWithinVariance, true, "Final balance not within expected range");
    assert.equal(withdrawn, true, "Funds not withdrawn");

  })
  
  it("Borrower can repay his own loan", async () => {
    const borrowerAccount = accounts[1];
    const lenderAccount = accounts[4];
    const secondLenderAccount = accounts[5];
    const initialBalanceLender = new BigNumber(await web3.eth.getBalance(lenderAccount));
    const initialBalanceSecondLender = new BigNumber(await web3.eth.getBalance(secondLenderAccount));
    const amountToPay = web3.utils.toWei("1.1", "ether");
    const loan = await p2pLendingInstance.getLoanInfo(0);
    const supposedBorrower = loan.borrower;
    const initialBloBalance = await bloTokenInstance.checkCredit({
      from: borrowerAccount,
    });
    assert.equal(
      supposedBorrower,
      borrowerAccount,
      "Address is different from address in loan."
    )
    const result = await p2pLendingInstance.repayLoan(0, {
      from: borrowerAccount,
      value: amountToPay,
    });
    truffleAssert.eventEmitted(result, "LoanRepaid");
    const updatedBloBalance = await bloTokenInstance.checkCredit({
      from: borrowerAccount,
    });
    assert.equal(
      updatedBloBalance.toNumber(),
      initialBloBalance.toNumber() + 50,
      "Collateral not returned to borrower correctly."
    );

    
    const updatedBalanceLender = new BigNumber(await web3.eth.getBalance(lenderAccount));
    const updatedBalanceSecondLender = new BigNumber(await web3.eth.getBalance(secondLenderAccount));
 
    const repaid = new BigNumber(web3.utils.toWei("0.55", "ether"));
    console.log(initialBalanceLender);
    console.log(repaid);
    console.log(updatedBalanceLender);

    assert.equal((initialBalanceLender.plus(repaid)).toNumber(), updatedBalanceLender.toNumber(), "Not balanced");
    assert.equal((initialBalanceSecondLender.plus(repaid)).toNumber(), updatedBalanceSecondLender.toNumber(), "Not balanced");
    const updatedLoan = await p2pLendingInstance.getLoanInfo(1);
    assert.equal(updatedLoan.repaid, true, "Loan repayment status not updated successfully.")
    truffleAssert.eventEmitted(result, "LoanRepaid");
  });

});
