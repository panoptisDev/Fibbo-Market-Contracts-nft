const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  balance,
} = require("@openzeppelin/test-helpers");

const { ZERO_ADDRESS } = constants;
const { expect } = require("chai");

const FibboNFT = artifacts.require("DefaultFibbo");
const FibboVerification = artifacts.require("FibboVerification");
const FibboMarkeplace = artifacts.require("FibboMarketplace");

contract(
  "Verification Artist System",
  function ([owner, toVerificate, feeRecipient]) {
    const firstTokenId = new BN("1");

    const randomTokenURI = "ipfs";
    beforeEach(async function () {
      this.marketplace = await FibboMarkeplace.new(feeRecipient, 200, {
        from: owner,
      });

      this.nft = await FibboNFT.new(this.marketplace.address, { from: owner });
      this.verification = await FibboVerification.new({ from: owner });

      this.nft.updateFibboVerification(this.verification.address, {
        from: owner,
      });
    });

    describe("Verify address", function () {
      it("reverts when its already verified", async function () {
        await this.verification.verificateAddress(toVerificate, {
          from: owner,
        });
        await expectRevert(
          this.verification.verificateAddress(toVerificate, {
            from: owner,
          }),
          "This address is already verified!"
        );
      });

      it("succesfully verify address", async function () {
        await this.verification.verificateAddress(toVerificate, {
          from: owner,
        });
      });

      it("reverts when we try to mint with unverified address", async function () {
        await expectRevert(
          this.nft.createToken("ipfs", { from: toVerificate }),
          "This address is not a verified artist!"
        );
      });

      it("succesfully minted item once verificated ", async function () {
        await this.verification.verificateAddress(toVerificate, {
          from: owner,
        });

        await this.nft.createToken("ipfs", { from: toVerificate });
      });
    });

    async function getGasCosts(receipt) {
      const tx = await web3.eth.getTransaction(receipt.tx);
      const gasPrice = new BN(tx.gasPrice);
      return gasPrice.mul(new BN(receipt.receipt.gasUsed));
    }
  }
);
