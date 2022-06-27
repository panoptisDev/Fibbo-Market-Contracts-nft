const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  balance,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;
const { expect } = require("chai");

const FibboVerification = artifacts.require("FibboVerification");
const FibboCommunity = artifacts.require("FibboCommunity");

contract("Community", function ([owner, proposer, depositor]) {
  const firstSuggestionId = new BN("1");
  const secondSuggestionId = new BN("2");
  const nonExistentSuggestionId = new BN("99");
  const totalAmount = new BN("40");
  const lowTotalAmount = new BN("5");
  const depositAmount = new BN("20");
  const totalDepositAmount = new BN("50");
  const title = "Add a new functionality";
  const desctiption = "Be nice to each other!";
  const proposerfee = 200;

  beforeEach(async function () {
    this.community = await FibboCommunity.new(proposerfee, {
      from: owner,
    });

    this.verification = await FibboVerification.new({ from: owner });

    this.community.updateFibboVerification(this.verification.address, {
      from: owner,
    });
  });

  describe("Create Suggestion", function () {
    it("reverts when total amount is lower than 10", async function () {
      await expectRevert(
        this.community.createSuggestion(
          title,
          desctiption,
          lowTotalAmount,
          proposer,
          {
            from: owner,
          }
        ),
        "Total amount must be higher than 10!"
      );
    });

    it("reverts when is not verified address", async function () {
      await expectRevert(
        this.community.createSuggestion(
          title,
          desctiption,
          totalAmount,
          proposer,
          {
            from: owner,
          }
        ),
        "Address is not verified!"
      );
    });

    it("Succesfully create suggestion", async function () {
      await this.verification.verificateAddress(proposer, {
        from: owner,
      });
      await this.community.createSuggestion(
        title,
        desctiption,
        totalAmount,
        proposer,
        {
          from: owner,
        }
      );
    });
  });

  describe("Deposit into Suggestion", function () {
    this.beforeEach(async function () {
      await this.verification.verificateAddress(proposer, {
        from: owner,
      });
      await this.community.createSuggestion(
        title,
        desctiption,
        totalAmount,
        proposer,
        {
          from: owner,
        }
      );
    });
    it("reverts when suggestion don't exists ", async function () {
      await expectRevert(
        this.community.addTokensToSuggestion(nonExistentSuggestionId, {
          from: depositor,
          value: depositAmount,
        }),
        "Suggestion does not exist!"
      );
    });

    it("reverts when address is not verified", async function () {
      await expectRevert(
        this.community.addTokensToSuggestion(firstSuggestionId, {
          from: depositor,
          value: depositAmount,
        }),
        "Sender is not a verified address!"
      );
    });

    it("Deposit succesfully on contract", async function () {
      const provider = ethers.provider;
      await this.verification.verificateAddress(depositor, {
        from: owner,
      });
      await this.community.addTokensToSuggestion(firstSuggestionId, {
        from: depositor,
        value: depositAmount,
      });

      const progress = await this.community.suggestionsProgress(
        firstSuggestionId
      );
      const contractBalance = await provider.getBalance(this.community.address);

      expect(progress === contractBalance);
    });

    it("reverts when suggestion has reached end and we deposit ", async function () {
      await this.verification.verificateAddress(depositor, {
        from: owner,
      });

      await this.community.addTokensToSuggestion(firstSuggestionId, {
        from: depositor,
        value: totalDepositAmount,
      });
      await expectRevert(
        this.community.addTokensToSuggestion(firstSuggestionId, {
          from: depositor,
          value: depositAmount,
        }),
        "Suggestion has reached the total amount!"
      );
    });
  });

  describe("Withdraw from suggestion", function () {
    this.beforeEach(async function () {
      await this.verification.verificateAddress(owner, {
        from: owner,
      });
      await this.verification.verificateAddress(proposer, {
        from: owner,
      });
      await this.verification.verificateAddress(depositor, {
        from: owner,
      });

      await this.community.createSuggestion(
        title,
        desctiption,
        totalAmount,
        proposer,
        {
          from: owner,
        }
      );
      await this.community.createSuggestion(
        title,
        desctiption,
        totalAmount,
        proposer,
        {
          from: owner,
        }
      );

      await this.community.addTokensToSuggestion(firstSuggestionId, {
        from: depositor,
        value: totalDepositAmount,
      });

      await this.community.addTokensToSuggestion(secondSuggestionId, {
        from: depositor,
        value: depositAmount,
      });
    });

    it("reverts when suggestion has not ended ", async function () {
      await expectRevert(
        this.community.withdrawFromSuggestion(
          secondSuggestionId,
          secondSuggestionId,
          {
            from: owner,
          }
        ),
        "Suggestion has not reached the total amount!"
      );
    });

    it("reverts when we're not the owner", async function () {
      await expectRevert(
        this.community.withdrawFromSuggestion(
          firstSuggestionId,
          firstSuggestionId,
          {
            from: depositor,
          }
        ),
        "Ownable: caller is not the owner"
      );
    });

    it("reverts when suggestion don't exist", async function () {
      await expectRevert(
        this.community.withdrawFromSuggestion(
          nonExistentSuggestionId,
          firstSuggestionId,
          {
            from: owner,
          }
        ),
        "Suggestion does not exist!"
      );
    });

    it("Withdraw succesfully from suggestion", async function () {
      const provider = ethers.provider;

      const progress = await this.community.suggestionsProgress(
        firstSuggestionId
      );

      expect(progress === totalDepositAmount);

      await this.community.withdrawFromSuggestion(
        firstSuggestionId,
        firstSuggestionId,
        { from: owner }
      );

      const contractBalance = await provider.getBalance(this.community.address);

      expect(contractBalance === depositAmount);
    });
  });

  async function getGasCosts(receipt) {
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = new BN(tx.gasPrice);
    return gasPrice.mul(new BN(receipt.receipt.gasUsed));
  }
});
