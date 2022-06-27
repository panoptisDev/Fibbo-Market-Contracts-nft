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
    beforeEach(async function () {
      this.marketplace = await FibboMarkeplace.new(feeRecipient, 200, {
        from: owner,
      });

      this.nft = await FibboNFT.new(this.marketplace.address, { from: owner });
      this.verification = await FibboVerification.new({ from: owner });

      this.nft.updateFibboVerification(this.verification.address, {
        from: owner,
      });
      this.marketplace.updateFibboVerification(this.verification.address, {
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

      it("succesfully verify address - inversor", async function () {
        await this.verification.verificateInversor(toVerificate, {
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

      it("succesfully buys and sells item ", async function () {
        await this.verification.verificateAddress(owner, {
          from: owner,
        });

        await this.nft.createToken("ipfs", { from: owner });

        await this.marketplace.listItem(this.nft.address, 1, 10, {
          from: owner,
        });

        await this.marketplace.buyItem(this.nft.address, 1, owner, {
          from: toVerificate,
          value: 10,
        });

        await this.verification.verificateInversor(toVerificate, {
          from: owner,
        });

        await this.nft.setApprovalForAll(this.marketplace.address, true, {
          from: toVerificate,
        });
        await this.marketplace.listItem(this.nft.address, 1, 12, {
          from: toVerificate,
        });
      });
    });

    describe("Unverify address", function () {
      it("reverts when we unverify and its not verified", async function () {
        await expectRevert(
          this.verification.unverifyAddress(toVerificate, {
            from: owner,
          }),
          "This address is not verified!"
        );
      });

      it("succesfully UnVerify address", async function () {
        await this.verification.verificateAddress(toVerificate, {
          from: owner,
        });
        await this.verification.unverifyAddress(toVerificate, {
          from: owner,
        });
      });

      it("reverts when we UnVerify address and we try to mint", async function () {
        await this.verification.verificateAddress(toVerificate, {
          from: owner,
        });
        await this.verification.unverifyAddress(toVerificate, {
          from: owner,
        });
        await expectRevert(
          this.nft.createToken("ipfs", { from: owner }),
          "This address is not a verified artist!"
        );
      });
    });

    async function getGasCosts(receipt) {
      const tx = await web3.eth.getTransaction(receipt.tx);
      const gasPrice = new BN(tx.gasPrice);
      return gasPrice.mul(new BN(receipt.receipt.gasUsed));
    }
  }
);
