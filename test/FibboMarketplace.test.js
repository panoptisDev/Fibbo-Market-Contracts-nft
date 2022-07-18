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
const FibboMarketplace = artifacts.require("FibboMarketplace");
const FibboVerification = artifacts.require("FibboVerification");

contract(
  "Core ERC721 tests for FibboNFT and Marketplace",
  function ([owner, minter, buyer, feeRecipient]) {
    const firstTokenId = new BN("1");
    const secondTokenId = new BN("2");
    const nonExistentTokenId = new BN("99");
    const platformFee = 200; // marketplace platform fee: 2.5%
    const price = new BN("10000000000000000000");
    const newPrice = new BN("500000000000000000");

    const randomTokenURI = "ipfs";
    beforeEach(async function () {
      this.marketplace = await FibboMarketplace.new(feeRecipient, platformFee, {
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

      this.verification.verificateAddress(owner, { from: owner });
      this.verification.verificateAddress(minter, { from: owner });

      this.marketplace.updatePlatformFee(platformFee, { from: owner });
      this.marketplace.updatePlatformFeeRecipient(feeRecipient, {
        from: owner,
      });

      this.nft.createToken(randomTokenURI, { from: minter });
      this.nft.createToken(randomTokenURI, { from: owner });
    });

    describe("Listing Item", function () {
      it("reverts when item no exists", async function () {
        await expectRevert(
          this.marketplace.listItem(
            this.nft.address,
            nonExistentTokenId,
            ZERO_ADDRESS,
            price,
            0,
            {
              from: minter,
            }
          ),
          "ERC721: owner query for nonexistent token"
        );
      });

      it("reverts when not owning NFT", async function () {
        await expectRevert(
          this.marketplace.listItem(
            this.nft.address,
            firstTokenId,
            ZERO_ADDRESS,
            price,
            0,
            {
              from: owner,
            }
          ),
          "Sender don't own item!"
        );
      });

      it("reverts when is already listed", async function () {
        await this.marketplace.listItem(
          this.nft.address,
          firstTokenId,
          ZERO_ADDRESS,
          price,
          0,
          {
            from: minter,
          }
        );
        await expectRevert(
          this.marketplace.listItem(
            this.nft.address,
            firstTokenId,
            ZERO_ADDRESS,
            price,
            0,
            {
              from: minter,
            }
          ),
          "already listed"
        );
      });

      it("successfuly lists item", async function () {
        await this.marketplace.listItem(
          this.nft.address,
          firstTokenId,
          ZERO_ADDRESS,
          price,
          0,
          {
            from: minter,
          }
        );
      });
    });

    /* 
    describe("Canceling Item", function () {
      this.beforeEach(async function () {
        await this.marketplace.listItem(this.nft.address, firstTokenId, price, {
          from: minter,
        });
      });

      it("reverts when item is not listed", async function () {
        await expectRevert(
          this.marketplace.cancelListing(this.nft.address, secondTokenId, {
            from: owner,
          }),
          "not listed item"
        );
      });

      it("reverts when not owning item", async function () {
        await expectRevert(
          this.marketplace.cancelListing(this.nft.address, firstTokenId, {
            from: owner,
          }),
          "not listed item"
        );
      });
      it("successfully cancel the item", async function () {
        await this.marketplace.cancelListing(this.nft.address, firstTokenId, {
          from: minter,
        });
      });
    });

    describe("Updating Item price", function () {
      this.beforeEach(async function () {
        await this.marketplace.listItem(this.nft.address, firstTokenId, price, {
          from: minter,
        });
      });

      it("reverts when item is not listed", async function () {
        await expectRevert(
          this.marketplace.updateListing(
            this.nft.address,
            secondTokenId,
            newPrice,
            {
              from: owner,
            }
          ),
          "not listed item"
        );
      });

      it("reverts when not owning item", async function () {
        await expectRevert(
          this.marketplace.updateListing(
            this.nft.address,
            firstTokenId,
            newPrice,
            {
              from: owner,
            }
          ),
          "not listed item"
        );
      });
      it("successfully cancel the item", async function () {
        await this.marketplace.updateListing(
          this.nft.address,
          firstTokenId,
          newPrice,
          {
            from: minter,
          }
        );
      });
    });

    describe("Buying Item", function () {
      this.beforeEach(async function () {
        await this.marketplace.listItem(this.nft.address, firstTokenId, price, {
          from: minter,
        });
      });

      it("reverts when seller doesnt own the item", async function () {
        await this.nft.safeTransferFrom(minter, owner, firstTokenId, {
          from: minter,
        });

        await expectRevert(
          this.marketplace.buyItem(this.nft.address, firstTokenId, minter, {
            from: buyer,
            value: price,
          }),
          "ERC721: transfer from incorrect owner"
        );
      });

      it("reverts when the amount is not enough", async function () {
        await expectRevert(
          this.marketplace.buyItem(this.nft.address, firstTokenId, minter, {
            from: buyer,
          }),
          "Not enough to buy item"
        );
      });

      it("successfully purchase item", async function () {
        const provider = ethers.provider;
        const feeBalanceTracker = await balance.tracker(feeRecipient, "ether");
        const minterBalanceTracker = await balance.tracker(minter, "ether");

        await this.marketplace.buyItem(this.nft.address, firstTokenId, minter, {
          from: buyer,
          value: price,
        });

        expect(await this.nft.ownerOf(firstTokenId)).to.be.equal(buyer);
        expect(await feeBalanceTracker.delta("ether")).to.be.bignumber.equal(
          "0.2"
        );
        expect(await minterBalanceTracker.delta("ether")).to.be.bignumber.equal(
          "9.8"
        );
      });
    }); */

    async function getGasCosts(receipt) {
      const tx = await web3.eth.getTransaction(receipt.tx);
      const gasPrice = new BN(tx.gasPrice);
      return gasPrice.mul(new BN(receipt.receipt.gasUsed));
    }
  }
);
