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

  it("Create a borrow request", async () => {
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

  it("Check only borrower can withdraw borrow request", async() => {
    const wrongBorrower = accounts[2];
    let isLineExecutedHere = false;
    try {
      await borrowRequestInstance.withdrawFromBorrowRequest(0, wrongBorrower, {from: wrongBorrower});
      isLineExecutedHere = true;
    } catch(e) {
      assert.equal(isLineExecutedHere, false, "Only borrower can withdraw from loan")
    }
  })
});

contract("P2PLending", function (accounts) {
  before(async () => {
    bloTokenInstance = await BloToken.deployed();
    borrowRequestInstance = await BorrowRequest.deployed();
    p2pLendingInstance = await P2PLending.deployed();
  });
  console.log("Testing P2P Lending contract");

  it("Users able to exchange ETH for bLo tokens", async () => {
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

  it("Create a borrow request and send collateral to the contract", async () => {
    // Account to test with
    const borrowerAccount = accounts[1];


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

  it("Check borrower cant fund his own borrow request", async() => {
    const borrowerAccount = accounts[1];
    const amountToFund = web3.utils.toWei("0.5", "ether");
    let isLineExecutedHere = false;
    try {
      await p2pLendingInstance.fundBorrowRequest(0, {
        from: borrowerAccount,
        value: amountToFund,
      });
      isLineExecutedHere = true;
    } catch(e) {
      assert.equal(isLineExecutedHere, false, "Borrower cant fund his own request");
    }
  })

  it("Lender can fund active borrow request", async () => {
    const lenderAccount = accounts[4];
    const amountToFund = web3.utils.toWei("0.5", "ether");
    const initialBalance = await web3.eth.getBalance(borrowRequestInstance.address);

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

    assert.equal(
      newCount.toNumber(),
      initialCount.toNumber() + 1,
      "Loan not created"
    );
  });

  it("Check only borrower can withdraw from loan", async() => {
    const wrongBorrower = accounts[2];
    let isLineExecutedHere = false;
    try {
      await p2pLendingInstance.withdrawFundsFromLoans(0, {from: wrongBorrower});
      isLineExecutedHere = true;
    } catch(e) {
      assert.equal(isLineExecutedHere, false, "Only borrower can withdraw from loan")
    }
  })

  it("Borrower can withdraw from the loan", async() => {
    const borrowerAccount = accounts[1];


    const borrowedAmt = await borrowRequestInstance.getAmount(0);


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

  it("Only Borrower can repay his loan", async() => {
    const wrongBorrower = accounts[2];
    const amountToPay = web3.utils.toWei("1.1", "ether");
    let isLineExecutedHere = false;
    try {
      await p2pLendingInstance.repayLoan(0, {
        from: wrongBorrower,
        value: amountToPay,
      });
      isLineExecutedHere = true;
    } catch(e) {
      assert.equal(isLineExecutedHere, false, "Only Borrower can repay loan");
    }
  })

  it("Check if collateral transferred to lenders when borrower miss repayment date", async() => {
    const originalExpiryDate = await p2pLendingInstance.getLoanExpiryDate(0);
    await p2pLendingInstance.setExpiryDate(0, 0);
    const amountToPay = web3.utils.toWei("1.1", "ether");
    const initialBloTokenBalanceLender = await bloTokenInstance.checkCredit({from: accounts[4]});
    const event = await p2pLendingInstance.repayLoan(0, {from: accounts[1], value: amountToPay});
    truffleAssert.eventEmitted(event, "LoanExpired");
    const updatedBloTokenBalanceLender = await bloTokenInstance.checkCredit({from: accounts[4]});
    const result = updatedBloTokenBalanceLender.toNumber() > initialBloTokenBalanceLender.toNumber();
    await p2pLendingInstance.setExpiryDate(0, originalExpiryDate);
    assert.equal(result, true, "Lender did not receive seized collateral");
  })

  it("Borrower can repay his own loan", async () => {
    const borrowerAccount = accounts[1];
    const lenderAccount = accounts[4];
    const secondLenderAccount = accounts[5];
    const initialBalanceLender = new BigNumber(await web3.eth.getBalance(lenderAccount));
    const initialBalanceSecondLender = new BigNumber(await web3.eth.getBalance(secondLenderAccount));
    const amountToPay = web3.utils.toWei("1.1", "ether");
    const loan = await p2pLendingInstance.getLoanInfo(0);
    const collateralAmount = (await borrowRequestInstance.getCollateralAmount(0)).toNumber();
    const loanLenders = await p2pLendingInstance.getLenders(0);

    const lenderAddresses = [lenderAccount, secondLenderAccount]
    const filteredLoanLenders = loanLenders.filter(entry => lenderAddresses.includes(entry[0]));
    const lentAmtValues = filteredLoanLenders.map(entry => entry[1]);

    const firstLenderRepayAmt = ((lentAmtValues[0] * (100 + loan.interest.toNumber())) / 100);
    const secondLenderRepayAmt = ((lentAmtValues[1] * (100 + loan.interest.toNumber())) / 100);

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
      initialBloBalance.toNumber() + collateralAmount,
      "Collateral not returned to borrower correctly."
    );


    const updatedBalanceLender = new BigNumber(await web3.eth.getBalance(lenderAccount));
    const updatedBalanceSecondLender = new BigNumber(await web3.eth.getBalance(secondLenderAccount));

    // const repaid = new BigNumber(web3.utils.toWei("0.55", "ether"));

    assert.equal((initialBalanceLender.plus(firstLenderRepayAmt)).toNumber(), updatedBalanceLender.toNumber(), "Not balanced");
    assert.equal((initialBalanceSecondLender.plus(secondLenderRepayAmt)).toNumber(), updatedBalanceSecondLender.toNumber(), "Not balanced");
    const updatedLoan = await p2pLendingInstance.getLoanInfo(0);
    assert.equal(updatedLoan.repaid, true, "Loan repayment status not updated successfully.")
    truffleAssert.eventEmitted(result, "LoanRepaid");
  });

  it("Check trust score updated", async () => {
    const borrowerAccount = accounts[1];
    let res = await p2pLendingInstance.getTrustScore(borrowerAccount);
    assert.equal(40, res, "Trust score not updated");
  })
});
