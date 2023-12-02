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

  it("Create Borrow Request from P2PLending contract", async () => {
    const initialBorrowReqCount =
      await borrowRequestInstance.borrowRequestCount();

    const amount = web3.utils.toWei("1", "ether");
    const currentTimestamp = Math.floor(new Date().getTime() / 1000);
    const repaymentDeadline = currentTimestamp + 24 * 60 * 60;
    const interest = 10;
    const duration = 30;
    const bloTokenCollateral = 50;

    await p2pLendingInstance.createNewBorrowRequest(
      amount,
      repaymentDeadline,
      interest,
      duration,
      bloTokenCollateral,
      { from: accounts[4] }
    );

    const newCount = await borrowRequestInstance.borrowRequestCount();
    assert.equal(
      newCount.toNumber(),
      initialBorrowReqCount.toNumber() + 1,
      "Borrow request not created"
    );
  });

  it("should create a borrow request and send collateral to the contract", async () => {
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
    await debug(
      p2pLendingInstance.createNewBorrowRequest(
        amount,
        repaymentDeadline,
        interest,
        duration,
        bloTokenCollateral,
        { from: borrowerAccount }
      )
    );

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

    // call fundBorrowRequest()
    await p2pLendingInstance.fundBorrowRequest(1, {
      from: lenderAccount,
      value: amountToFund,
    });

    // check that lender got added into lenders mapping of the specific borrow request
    // get LenderInfo[] of borrow request by borrow request id
    const exists = await borrowRequestInstance.checkAddressExists(
      lenderAccount,
      borrowRequestId
    );
    assert.equal(
      exists,
      true,
      "Lender not in lenders list, funding did not execute correctly"
    );
  });
});
