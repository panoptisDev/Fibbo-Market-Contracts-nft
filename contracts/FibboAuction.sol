// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

interface IFibboAddressRegistry {
    function artion() external view returns (address);

    function marketplace() external view returns (address);

    function tokenRegistry() external view returns (address);
}

interface IFibboMarketplace {
    function minters(address, uint256) external view returns (address);

    function royalties(address, uint256) external view returns (uint16);
}

interface IFibboTokenRegistry {
    function enabled(address) external returns (bool);
}

/**
 * @notice Secondary sale auction contract for NFTs
 */
contract FibboAuction is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable
{
    using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;

    /// @notice Event emitted only on construction. To be used by indexers
    event FantomAuctionContractDeployed();

    event PauseToggled(bool isPaused);

    event AuctionCreated(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address payToken
    );

    event UpdateAuctionEndTime(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 endTime
    );

    event UpdateAuctionStartTime(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 startTime
    );

    event UpdateAuctionReservePrice(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address payToken,
        uint256 reservePrice
    );

    event UpdateMinBidIncrement(uint256 minBidIncrement);

    event UpdateBidWithdrawalLockTime(uint256 bidWithdrawalLockTime);

    event BidPlaced(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event BidWithdrawn(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event BidRefunded(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event AuctionResulted(
        address oldOwner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed winner,
        address payToken,
        uint256 winningBid,
        uint256 marketFee,
        uint256 royaltyFee
    );

    event AuctionCancelled(address indexed nftAddress, uint256 indexed tokenId);

    /// @notice Parameters of an auction
    struct Auction {
        address owner;
        address payToken;
        uint256 minBid;
        uint256 reservePrice;
        uint256 buyNowPrice;
        uint256 startTime;
        uint256 endTime;
        bool resulted;
    }

    /// @notice Information about the sender that placed a bit on an auction
    struct HighestBid {
        address payable bidder;
        uint256 bid;
        uint256 lastBidTime;
    }

    /// @notice ERC721 Address -> Token ID -> Auction Parameters
    mapping(address => mapping(uint256 => Auction)) public auctions;

    /// @notice ERC721 Address -> Token ID -> highest bidder info (if a bid has been received)
    mapping(address => mapping(uint256 => HighestBid)) public highestBids;

    /// @notice globally and across all auctions, the amount by which a bid has to increase
    uint256 public minBidIncrement = 1;

    /// @notice global bid withdrawal lock time
    uint256 public bidWithdrawalLockTime = 20 minutes;

    /// @notice global platform fee, assumed to always be to 1 decimal place i.e. 25 = 2.5%
    uint16 public platformFee;

    /// @notice where to send platform fee funds to
    address payable public platformFeeRecipient;

    /// @notice Address registry
    IFibboAddressRegistry public addressRegistry;

    /// @notice for switching off auction creations, bids and withdrawals
    bool public isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "contract paused");
        _;
    }

    modifier onlyMarketplace() {
        require(
            addressRegistry.marketplace() == _msgSender(),
            "not marketplace contract"
        );
        _;
    }

    constructor(address forwarder)
        public
        ERC2771ContextUpgradeable(forwarder)
    {}

    /// @notice Contract initializer
    function initialize(
        address payable _platformFeeRecipient,
        uint16 _platformFee
    ) public initializer {
        require(
            _platformFeeRecipient != address(0),
            "Invalid Platform Fee Recipient"
        );

        platformFeeRecipient = _platformFeeRecipient;
        platformFee = _platformFee;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function _msgSender()
        internal
        view
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address sender)
    {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData()
        internal
        view
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    /**
     @notice Creates a new auction for a given item
     @dev Only the owner of item can create an auction and must have approved the contract
     @dev In addition to owning the item, the sender also has to have the MINTER role.
     @dev End time for the auction must be in the future.
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     @param _payToken Paying token
     @param _reservePrice Item cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        address _payToken,
        uint256 _reservePrice,
        uint256 _buyNowPrice,
        uint256 _startTimestamp,
        bool minBidReserve,
        uint256 _endTimestamp
    ) external {
        // Ensure this contract is approved to move the token
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == _msgSender() &&
                IERC721(_nftContract).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
            "not owner and or contract not approved"
        );

        require(
            _payToken == address(0) ||
                (addressRegistry.tokenRegistry() != address(0) &&
                    IFibboTokenRegistry(addressRegistry.tokenRegistry())
                        .enabled(_payToken)),
            "invalid pay token"
        );

        _createAuction(
            _nftContract,
            _tokenId,
            _payToken,
            _reservePrice,
            _buyNowPrice,
            _startTimestamp,
            minBidReserve,
            _endTimestamp
        );
    }

    /**
     @notice Places a new bid, out bidding the existing bidder if found and criteria is reached
     @dev Only callable when the auction is open
     @dev Bids from smart contracts are prohibited to prevent griefing with always reverting receiver
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     @param _bidAmount Bid amount
     */
    function placeBid(
        address _nftContract,
        uint256 _tokenId,
        uint256 _bidAmount
    ) external nonReentrant whenNotPaused {
        // Check the auction to see if this is a valid bid
        Auction memory auction = auctions[_nftContract][_tokenId];

        // Ensure auction is in flight
        require(
            _getNow() >= auction.startTime && _getNow() <= auction.endTime,
            "bidding outside of the auction window"
        );
        require(
            auction.payToken != address(0),
            "ERC20 method used for FTM auction"
        );

        _placeBid(_nftContract, _tokenId, _bidAmount);
    }

    function _placeBid(
        address _nftContract,
        uint256 _tokenId,
        uint256 _bidAmount
    ) internal whenNotPaused {
        Auction storage auction = auctions[_nftContract][_tokenId];

        if (auction.minBid == auction.reservePrice) {
            require(
                _bidAmount >= auction.reservePrice,
                "bid cannot be lower than reserve price"
            );
        }

        // Ensure bid adheres to outbid increment and threshold
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];
        uint256 minBidRequired = highestBid.bid + (minBidIncrement);

        require(
            _bidAmount >= minBidRequired,
            "failed to outbid highest bidder"
        );

        if (auction.payToken != address(0)) {
            IERC20 payToken = IERC20(auction.payToken);
            require(
                payToken.transferFrom(_msgSender(), address(this), _bidAmount),
                "insufficient balance or not approved"
            );
        }

        // Refund existing top bidder if found
        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(
                _nftContract,
                _tokenId,
                highestBid.bidder,
                highestBid.bid
            );
        }

        // assign top bidder and bid time
        highestBid.bidder = payable(_msgSender());
        highestBid.bid = _bidAmount;
        highestBid.lastBidTime = _getNow();

        emit BidPlaced(_nftContract, _tokenId, _msgSender(), _bidAmount);
    }

    /**
     @notice Allows the hightest bidder to withdraw the bid (after 12 hours post auction's end) 
     @dev Only callable by the existing top bidder
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     */
    function withdrawBid(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
        whenNotPaused
    {
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];

        // Ensure highest bidder is the caller
        require(
            highestBid.bidder == _msgSender(),
            "you are not the highest bidder"
        );

        uint256 _endTime = auctions[_nftContract][_tokenId].endTime;

        require(
            _getNow() > _endTime && (_getNow() - _endTime >= 43200),
            "can withdraw only after 12 hours (after auction ended)"
        );

        uint256 previousBid = highestBid.bid;

        // Clean up the existing top bid
        delete highestBids[_nftContract][_tokenId];

        // Refund the top bidder
        _refundHighestBidder(
            _nftContract,
            _tokenId,
            payable(_msgSender()),
            previousBid
        );

        emit BidWithdrawn(_nftContract, _tokenId, _msgSender(), previousBid);
    }

    //////////
    // Admin /
    //////////

    /**
     @notice Closes a finished auction and rewards the highest bidder
     @dev Only admin or smart contract
     @dev Auction can only be resulted if there has been a bidder and reserve met.
     @dev If there have been no bids, the auction needs to be cancelled instead using `cancelAuction()`
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     */
    function resultAuction(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
        onlyOwner
    {
        // Check the auction to see if it can be resulted
        Auction storage auction = auctions[_nftContract][_tokenId];

        // Check the auction real
        require(auction.endTime > 0, "no auction exists");

        // Check the auction has ended
        require(_getNow() > auction.endTime, "auction not ended");

        // Ensure auction not already resulted
        require(!auction.resulted, "auction already resulted");

        // Get info on who the highest bidder is
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];

        address winner = highestBid.bidder;
        uint256 winningBid = highestBid.bid;

        // Ensure there is a winner
        require(winner != address(0), "no open bids");
        require(
            winningBid >= auction.reservePrice,
            "highest bid is below reservePrice"
        );

        // Ensure this contract is approved to move the token
        require(
            IERC721(_nftContract).isApprovedForAll(owner(), address(this)),
            "auction not approved"
        );

        // Result the auction
        auction.resulted = true;

        // Clean up the highest bid
        delete highestBids[_nftContract][_tokenId];

        uint256 payAmount;
        IERC20 payToken = IERC20(auction.payToken);

        uint256 platformFeeAboveReserve = 0;
        if (winningBid > auction.reservePrice) {
            // Work out total above the reserve
            uint256 aboveReservePrice = winningBid - auction.reservePrice;

            // Work out platform fee from above reserve amount
            platformFeeAboveReserve = (aboveReservePrice * platformFee) / 10000;

            require(
                payToken.transfer(
                    platformFeeRecipient,
                    platformFeeAboveReserve
                ),
                "Failed to pay fees"
            );

            // Send remaining to designer
            payAmount = winningBid - platformFeeAboveReserve;
        } else {
            payAmount = winningBid;
        }

        IFibboMarketplace marketplace = IFibboMarketplace(
            addressRegistry.marketplace()
        );

        uint256 royaltyFee = 0;

        if (
            marketplace.minters(_nftContract, _tokenId) != address(0) &&
            marketplace.royalties(_nftContract, _tokenId) != 0
        ) {
            IERC20 payToken = IERC20(auction.payToken);
            royaltyFee =
                (payAmount * marketplace.royalties(_nftContract, _tokenId)) /
                10000;

            require(
                payToken.transfer(
                    marketplace.minters(_nftContract, _tokenId),
                    royaltyFee
                ),
                "failed to send the owner their royalties"
            );
            payAmount = payAmount - royaltyFee;
        }

        if (payAmount > 0) {
            require(
                payToken.transfer(auction.owner, payAmount),
                "failed to send the owner the auction balance"
            );
        }

        // Transfer the token to the winner
        IERC721(_nftContract).safeTransferFrom(
            IERC721(_nftContract).ownerOf(_tokenId),
            winner,
            _tokenId
        );

        emit AuctionResulted(
            auction.owner,
            _nftContract,
            _tokenId,
            winner,
            auction.payToken,
            winningBid,
            platformFeeAboveReserve,
            royaltyFee
        );

        // Remove auction
        delete auctions[_nftContract][_tokenId];
    }

    /**
     @notice Closes a finished auction by buyNow
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     */
    function buyNow(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
    {
        // Check the auction to see if it can be resulted
        Auction storage auction = auctions[_nftContract][_tokenId];

        // Check the auction real
        require(auction.endTime > 0, "no auction exists");

        // Check the auction has not ended
        require(_getNow() < auction.endTime, "auction  has ended");

        // Ensure auction not already resulted
        require(!auction.resulted, "auction already resulted");

        // Get info on who the highest bidder is
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];

        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(
                _nftContract,
                _tokenId,
                highestBid.bidder,
                highestBid.bid
            );

            // Clear up highest bid
            delete highestBids[_nftContract][_tokenId];
        }

        // Ensure this contract is approved to move the token
        require(
            IERC721(_nftContract).isApprovedForAll(_msgSender(), address(this)),
            "auction not approved"
        );

        // Result the auction
        auction.resulted = true;

        uint256 payAmount;
        IERC20 payToken = IERC20(auction.payToken);

        // Work out total above the reserve
        uint256 aboveReservePrice = auction.buyNowPrice - auction.reservePrice;

        // Work out platform fee from above reserve amount
        uint256 platformFeeAboveReserve = (aboveReservePrice * platformFee) /
            10000;

        payToken.safeTransferFrom(
            _msgSender(),
            platformFeeRecipient,
            platformFeeAboveReserve
        );

        // Send remaining to designer
        payAmount = auction.buyNowPrice - platformFeeAboveReserve;

        IFibboMarketplace marketplace = IFibboMarketplace(
            addressRegistry.marketplace()
        );

        uint256 royaltyFee = 0;

        if (
            marketplace.minters(_nftContract, _tokenId) != address(0) &&
            marketplace.royalties(_nftContract, _tokenId) != 0
        ) {
            royaltyFee =
                (payAmount * marketplace.royalties(_nftContract, _tokenId)) /
                10000;

            payToken.safeTransferFrom(
                _msgSender(),
                marketplace.minters(_nftContract, _tokenId),
                royaltyFee
            );

            payAmount = payAmount - royaltyFee;
        }

        if (payAmount > 0) {
            payToken.safeTransferFrom(_msgSender(), auction.owner, payAmount);
        }

        // Transfer the token to the winner
        IERC721(_nftContract).safeTransferFrom(
            IERC721(_nftContract).ownerOf(_tokenId),
            _msgSender(),
            _tokenId
        );

        emit AuctionResulted(
            auction.owner,
            _nftContract,
            _tokenId,
            _msgSender(),
            auction.payToken,
            auction.buyNowPrice,
            platformFeeAboveReserve,
            royaltyFee
        );

        // Remove auction
        delete auctions[_nftContract][_tokenId];
    }

    /**
     @notice Closes a finished auction that has not been completed
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the item being auctioned
     */
    function clearAuction(address _nftContract, uint256 _tokenId)
        external
        onlyOwner
    {
        Auction memory auction = auctions[_nftContract][_tokenId];

        address auctionOwner = auction.owner;

        // Check the auction real
        require(auction.endTime > 0, "no auction exists");

        // Check the auction has ended
        require(_getNow() > auction.endTime, "auction not ended");

        // Ensure auction not already resulted
        require(!auction.resulted, "auction already resulted");

        // Ensure this contract is approved to move the token
        require(
            IERC721(_nftContract).isApprovedForAll(owner(), address(this)),
            "auction not approved"
        );

        // Result the auction
        auction.resulted = true;

        _cancelAuction(_nftContract, _tokenId);
    }

    /**
     @notice Cancels and inflight and un-resulted auctions, returning the funds to the top bidder if found
     @dev Only item owner
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     */
    function cancelAuction(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
    {
        // Check valid and not resulted
        Auction memory auction = auctions[_nftContract][_tokenId];

        require(
            IERC721(_nftContract).ownerOf(_tokenId) == _msgSender() &&
                _msgSender() == auction.owner,
            "sender must be owner"
        );
        // Check auction is real
        require(auction.endTime > 0, "no auction exists");
        // Check auction not already resulted
        require(!auction.resulted, "auction already resulted");

        _cancelAuction(_nftContract, _tokenId);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external onlyOwner {
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the amount by which bids have to increase, across all auctions
     @dev Only admin
     @param _minBidIncrement New bid step in WEI
     */
    function updateMinBidIncrement(uint256 _minBidIncrement)
        external
        onlyOwner
    {
        minBidIncrement = _minBidIncrement;
        emit UpdateMinBidIncrement(_minBidIncrement);
    }

    /**
     @notice Update the global bid withdrawal lockout time
     @dev Only admin
     @param _bidWithdrawalLockTime New bid withdrawal lock time
     */
    function updateBidWithdrawalLockTime(uint256 _bidWithdrawalLockTime)
        external
        onlyOwner
    {
        bidWithdrawalLockTime = _bidWithdrawalLockTime;
        emit UpdateBidWithdrawalLockTime(_bidWithdrawalLockTime);
    }

    /**
     @notice Update the current reserve price for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _reservePrice New Ether reserve price (WEI value)
     */
    function updateAuctionReservePrice(
        address _nftContract,
        uint256 _tokenId,
        uint256 _reservePrice
    ) external {
        Auction storage auction = auctions[_nftContract][_tokenId];

        require(_msgSender() == auction.owner, "sender must be item owner");

        // Ensure auction not already resulted
        require(!auction.resulted, "auction already resulted");

        require(auction.endTime > 0, "no auction exists");

        auction.reservePrice = _reservePrice;
        emit UpdateAuctionReservePrice(
            _nftContract,
            _tokenId,
            auction.payToken,
            _reservePrice
        );
    }

    /**
     @notice Update the current start time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _startTime New start time (unix epoch in seconds)
     */
    function updateAuctionStartTime(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startTime
    ) external {
        Auction storage auction = auctions[_nftContract][_tokenId];

        require(_msgSender() == auction.owner, "sender must be owner");

        require(_startTime > 0, "invalid start time");

        require(auction.startTime + 60 > _getNow(), "auction already started");

        require(
            _startTime + 300 < auction.endTime,
            "start time should be less than end time (by 5 minutes)"
        );

        // Ensure auction not already resulted
        require(!auction.resulted, "auction already resulted");

        require(auction.endTime > 0, "no auction exists");

        auction.startTime = _startTime;
        emit UpdateAuctionStartTime(_nftContract, _tokenId, _startTime);
    }

    /**
     @notice Update the current end time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _endTimestamp New end time (unix epoch in seconds)
     */
    function updateAuctionEndTime(
        address _nftContract,
        uint256 _tokenId,
        uint256 _endTimestamp
    ) external {
        Auction storage auction = auctions[_nftContract][_tokenId];

        require(_msgSender() == auction.owner, "sender must be owner");

        // Check the auction has not ended
        require(_getNow() < auction.endTime, "auction already ended");

        require(auction.endTime > 0, "no auction exists");
        require(
            auction.startTime < _endTimestamp,
            "end time must be greater than start"
        );
        require(
            _endTimestamp > _getNow() + 300,
            "auction should end after 5 minutes"
        );

        auction.endTime = _endTimestamp;
        emit UpdateAuctionEndTime(_nftContract, _tokenId, _endTimestamp);
    }

    /**
     @notice Update FantomAddressRegistry contract
     @dev Only admin
     */
    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IFibboAddressRegistry(_registry);
    }

    ///////////////
    // Accessors //
    ///////////////

    /**
     @notice Method for getting all info about the auction
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     */
    function getAuction(address _nftContract, uint256 _tokenId)
        external
        view
        returns (
            address _owner,
            address _payToken,
            uint256 _reservePrice,
            uint256 _buyNowPrice,
            uint256 _startTime,
            uint256 _endTime,
            bool _resulted,
            uint256 minBid
        )
    {
        Auction storage auction = auctions[_nftContract][_tokenId];
        return (
            auction.owner,
            auction.payToken,
            auction.reservePrice,
            auction.buyNowPrice,
            auction.startTime,
            auction.endTime,
            auction.resulted,
            auction.minBid
        );
    }

    /**
     @notice Method for getting all info about the highest bidder
     @param _tokenId Token ID of the NFT being auctioned
     */
    function getHighestBidder(address _nftContract, uint256 _tokenId)
        external
        view
        returns (
            address payable _bidder,
            uint256 _bid,
            uint256 _lastBidTime
        )
    {
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];
        return (highestBid.bidder, highestBid.bid, highestBid.lastBidTime);
    }

    /////////////////////////
    // Internal and Private /
    /////////////////////////

    function _getNow() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an auction
     @param _nftContract ERC 721 Address
     @param _tokenId Token ID of the NFT being auctioned
     @param _payToken Paying token
     @param _reservePrice Item cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function _createAuction(
        address _nftContract,
        uint256 _tokenId,
        address _payToken,
        uint256 _reservePrice,
        uint256 _buyNowPrice,
        uint256 _startTimestamp,
        bool minBidReserve,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(
            auctions[_nftContract][_tokenId].endTime == 0,
            "auction already started"
        );

        // Check end time not before start time and that end is in the future
        require(
            _endTimestamp >= _startTimestamp + 300,
            "end time must be greater than start (by 5 minutes)"
        );

        require(_startTimestamp > _getNow(), "invalid start time");

        uint256 minimumBid = 0;

        if (minBidReserve) {
            minimumBid = _reservePrice;
        }

        require(
            _buyNowPrice > _reservePrice,
            "The buy now price must be higher than the reserved"
        );

        require(
            _buyNowPrice >= _reservePrice * 2,
            "The buy now price must be higher than the double of reserved"
        );

        // Setup the auction
        auctions[_nftContract][_tokenId] = Auction({
            owner: _msgSender(),
            payToken: _payToken,
            minBid: minimumBid,
            buyNowPrice: _buyNowPrice,
            reservePrice: _reservePrice,
            startTime: _startTimestamp,
            endTime: _endTimestamp,
            resulted: false
        });

        emit AuctionCreated(_nftContract, _tokenId, _payToken);
    }

    function _cancelAuction(address _nftContract, uint256 _tokenId) private {
        // refund existing top bidder if found
        HighestBid storage highestBid = highestBids[_nftContract][_tokenId];
        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(
                _nftContract,
                _tokenId,
                highestBid.bidder,
                highestBid.bid
            );

            // Clear up highest bid
            delete highestBids[_nftContract][_tokenId];
        }

        // Remove auction and top bidder
        delete auctions[_nftContract][_tokenId];

        emit AuctionCancelled(_nftContract, _tokenId);
    }

    /**
     @notice Used for sending back escrowed funds from a previous bid
     @param _currentHighestBidder Address of the last highest bidder
     @param _currentHighestBid Ether or Mona amount in WEI that the bidder sent when placing their bid
     */
    function _refundHighestBidder(
        address _nftContract,
        uint256 _tokenId,
        address payable _currentHighestBidder,
        uint256 _currentHighestBid
    ) private {
        Auction memory auction = auctions[_nftContract][_tokenId];
        if (auction.payToken == address(0)) {
            // refund previous best (if bid exists)
            (bool successRefund, ) = _currentHighestBidder.call{
                value: _currentHighestBid
            }("");
            require(successRefund, "failed to refund previous bidder");
        } else {
            IERC20 payToken = IERC20(auction.payToken);
            require(
                payToken.transfer(_currentHighestBidder, _currentHighestBid),
                "failed to refund previous bidder"
            );
        }
        emit BidRefunded(
            _nftContract,
            _tokenId,
            _currentHighestBidder,
            _currentHighestBid
        );
    }

    /**
     * @notice Reclaims ERC20 Compatible tokens for entire balance
     * @dev Only access controls admin
     * @param _tokenContract The address of the token contract
     */
    function reclaimERC20(address _tokenContract) external onlyOwner {
        require(_tokenContract != address(0), "Invalid address");
        IERC20 token = IERC20(_tokenContract);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(_msgSender(), balance), "Transfer failed");
    }
}
