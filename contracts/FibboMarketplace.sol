// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

interface IFibboTokenRegistry {
    function enabled(address) external view returns (bool);
}

interface IFibboPriceFeed {
    function wFTM() external view returns (address);

    function getPrice(address) external view returns (int256, uint8);
}

interface IFibboAuction {
    function auctions(address, uint256)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            bool
        );
}

interface IFibboAddressRegistry {
    function fibboCollection() external view returns (address);

    function marketplace() external view returns (address);

    function community() external view returns (address);

    function auction() external view returns (address);

    function tokenRegistry() external view returns (address);
}

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);

    function checkIfVerifiedInversor(address) external view returns (bool);
}

contract FibboMarketplace is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable
{
    //using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;

    /// @notice Structure for listed items

    event ItemListed(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 startingTime
    );
    event ItemSold(
        address indexed seller,
        address indexed buyer,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 fee,
        uint256 royaltyFee
    );
    event ItemUpdated(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 newPrice
    );
    event ItemCanceled(
        address indexed owner,
        address indexed nft,
        uint256 tokenId
    );
    event OfferCreated(
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    event OfferModified(
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    event OfferCanceled(
        address indexed creator,
        address indexed nft,
        uint256 tokenId
    );

    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    struct Listing {
        address payToken;
        uint256 price;
        uint256 startingTime;
    }

    /// @notice Structure for offer
    struct Offer {
        IERC20 payToken;
        uint256 price;
        uint256 deadline;
    }

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /// @notice Platform fee
    uint16 public platformFee;
    /// @notice Platform fee receipient
    address payable public feeReceipient;
    /// @notice NftAddress -> Token ID -> Minter

    /// @notice Address registry
    IFibboAddressRegistry public addressRegistry;

    IFibboVerification fibboVerification;

    mapping(address => mapping(uint256 => address)) public minters;

    mapping(address => mapping(uint256 => uint16)) public royalties;

    /// @notice NftAddress -> Token ID -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => Listing)))
        public listings;

    /// @notice NftAddress -> Token ID -> Offerer -> Offer
    mapping(address => mapping(uint256 => mapping(address => Offer)))
        public offers;

    address public immutable forwarder;

    constructor(address _forwarder)
        public
        ERC2771ContextUpgradeable(_forwarder)
    {
        forwarder = _forwarder;
    }

    /// @notice Contract initializer
    function initialize(address payable _feeRecipient, uint16 _platformFee)
        public
        initializer
    {
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;

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

    modifier isListed(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftContract][_tokenId][_owner];
        require(listing.price > 0, "not listed item");
        _;
    }

    modifier isVerifiedAddress(address _address) {
        bool isValidAddress = fibboVerification.checkIfVerified(_address);
        if (!isValidAddress) {
            bool isValidInversor = fibboVerification.checkIfVerifiedInversor(
                _address
            );
            require(isValidInversor, "Address is not verified");
        }

        _;
    }

    modifier validListing(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listedItem = listings[_nftContract][_tokenId][_owner];

        _validOwner(_nftContract, _tokenId, _owner);

        require(_getNow() >= listedItem.startingTime, "item not buyable");
        _;
    }

    modifier notListed(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftContract][_tokenId][_owner];
        require(listing.price == 0, "already listed");
        _;
    }

    modifier offerExists(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) {
        Offer memory offer = offers[_nftContract][_tokenId][_creator];
        require(offer.deadline > _getNow(), "offer not exists or expired");
        _;
    }

    modifier offerNotExists(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) {
        Offer memory offer = offers[_nftContract][_tokenId][_creator];
        require(
            offer.price == 0 || offer.deadline <= _getNow(),
            "offer already created"
        );
        _;
    }

    /// @notice Method for registering royalties
    /// @param _minter Token ID of NFT
    /// @param _nftContract Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _royalty Royaltie percentatge
    function registerRoyalty(
        address _minter,
        address _nftContract,
        uint256 _tokenId,
        uint16 _royalty
    ) external {
        minters[_nftContract][_tokenId] = _minter;
        royalties[_nftContract][_tokenId] = _royalty;
    }

    /// @notice Method for listing NFT
    function listItem(
        address _nftContract,
        uint256 _tokenId,
        address _payToken,
        uint256 _price,
        uint256 _startingTime
    )
        external
        isVerifiedAddress(_msgSender())
        notListed(_nftContract, _tokenId, _msgSender())
    {
        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftContract);
            require(
                nft.ownerOf(_tokenId) == _msgSender(),
                "Sender don't own item!"
            );
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "Item is not approved!"
            );
        } else {
            revert("Invalid nft contract!");
        }

        _validPayToken(_payToken);

        listings[_nftContract][_tokenId][_msgSender()] = Listing(
            _payToken,
            _price,
            _startingTime
        );

        emit ItemListed(
            _msgSender(),
            _nftContract,
            _tokenId,
            _payToken,
            _price,
            _startingTime
        );
    }

    /// @notice Method for canceling listed NFT
    function cancelListing(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
        isListed(_nftContract, _tokenId, _msgSender())
        isVerifiedAddress(_msgSender())
    {
        _cancelListing(_nftContract, _tokenId, _msgSender());
    }

    /// @notice Method for updating listed NFT
    /// @param _nftContract Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _payToken Paying token
    /// @param _newPrice New sale price
    function updateListing(
        address _nftContract,
        uint256 _tokenId,
        address _payToken,
        uint256 _newPrice
    )
        external
        nonReentrant
        isListed(_nftContract, _tokenId, _msgSender())
        isVerifiedAddress(_msgSender())
    {
        Listing storage listedItem = listings[_nftContract][_tokenId][
            _msgSender()
        ];

        _validOwner(_nftContract, _tokenId, _msgSender());

        _validPayToken(_payToken);

        listedItem.payToken = _payToken;
        listedItem.price = _newPrice;
        emit ItemUpdated(
            _msgSender(),
            _nftContract,
            _tokenId,
            _payToken,
            _newPrice
        );
    }

    /// @notice Method for buying listed NFT
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    /// @param _payToken Paying token
    /// @param _owner Current Nft owner

    function buyItem(
        address _nftContract,
        uint256 _tokenId,
        address _payToken,
        address payable _owner
    ) external payable nonReentrant isListed(_nftContract, _tokenId, _owner) {
        Listing memory listedItem = listings[_nftContract][_tokenId][_owner];

        uint256 marketFee = (listedItem.price * platformFee) / 10000;
        uint256 feeAmount = marketFee;

        IERC20(_payToken).safeTransferFrom(
            _msgSender(),
            feeReceipient,
            feeAmount
        );

        uint256 royaltyFee = 0;

        if (
            minters[_nftContract][_tokenId] != address(0) &&
            royalties[_nftContract][_tokenId] != 0
        ) {
            royaltyFee =
                ((listedItem.price - feeAmount) *
                    royalties[_nftContract][_tokenId]) /
                10000;

            IERC20(_payToken).safeTransferFrom(
                _msgSender(),
                minters[_nftContract][_tokenId],
                royaltyFee
            );

            feeAmount = feeAmount + royaltyFee;
        }

        IERC20(_payToken).safeTransferFrom(
            _msgSender(),
            _owner,
            listedItem.price - feeAmount
        );
        // Transfer NFT to buyer

        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftContract).safeTransferFrom(
                _owner,
                _msgSender(),
                _tokenId
            );
        }

        emit ItemSold(
            _owner,
            _msgSender(),
            _nftContract,
            _tokenId,
            _payToken,
            listedItem.price,
            marketFee,
            royaltyFee
        );

        delete (listings[_nftContract][_tokenId][_owner]);
    }

    /// @notice Method for offering item
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    /// @param _payToken Paying token
    /// @param _price price
    function createOffer(
        address _nftContract,
        uint256 _tokenId,
        IERC20 _payToken,
        uint256 _price,
        uint256 _deadline
    ) external offerNotExists(_nftContract, _tokenId, _msgSender()) {
        require(
            IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721) ||
                IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC1155),
            "invalid nft address"
        );

        IFibboAuction auction = IFibboAuction(addressRegistry.auction());

        (, , , uint256 startTime, , bool resulted) = auction.auctions(
            _nftContract,
            _tokenId
        );

        require(
            startTime == 0 || resulted == true,
            "cannot place an offer if auction is going on"
        );

        require(_deadline > _getNow(), "invalid expiration");

        _validPayToken(address(_payToken));

        offers[_nftContract][_tokenId][_msgSender()] = Offer(
            _payToken,
            _price,
            _deadline
        );

        emit OfferCreated(
            _msgSender(),
            _nftContract,
            _tokenId,
            address(_payToken),
            _price,
            _deadline
        );
    }

    /// @notice Method for modify exiting offer
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    /// @param _payToken Paying token
    /// @param _price price
    function modifyOffer(
        address _nftContract,
        uint256 _tokenId,
        IERC20 _payToken,
        uint256 _price,
        uint256 _deadline
    ) external offerExists(_nftContract, _tokenId, _msgSender()) {
        require(
            IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721) ||
                IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC1155),
            "invalid nft address"
        );

        IFibboAuction auction = IFibboAuction(addressRegistry.auction());

        (, , , uint256 startTime, , bool resulted) = auction.auctions(
            _nftContract,
            _tokenId
        );

        require(
            startTime == 0 || resulted == true,
            "cannot place an offer if auction is going on"
        );

        require(_deadline > _getNow(), "invalid expiration");

        _validPayToken(address(_payToken));

        offers[_nftContract][_tokenId][_msgSender()] = Offer(
            _payToken,
            _price,
            _deadline
        );

        emit OfferModified(
            _msgSender(),
            _nftContract,
            _tokenId,
            address(_payToken),
            _price,
            _deadline
        );
    }

    /// @notice Method for canceling the offer
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    function cancelOffer(address _nftContract, uint256 _tokenId)
        external
        offerExists(_nftContract, _tokenId, _msgSender())
    {
        delete (offers[_nftContract][_tokenId][_msgSender()]);
        emit OfferCanceled(_msgSender(), _nftContract, _tokenId);
    }

    /// @notice Method for canceling all the non acceptedOffers
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    function cleanOffers(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) external onlyOwner {
        Offer memory offer = offers[_nftContract][_tokenId][_creator];
        require(offer.price != 0, "offer not exists");
        delete (offers[_nftContract][_tokenId][_creator]);
        emit OfferCanceled(_creator, _nftContract, _tokenId);
    }

    /// @notice Method for accepting the offer
    /// @param _nftContract NFT contract address
    /// @param _tokenId TokenId
    /// @param _creator Offer creator address
    function acceptOffer(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) external nonReentrant offerExists(_nftContract, _tokenId, _creator) {
        Offer memory offer = offers[_nftContract][_tokenId][_creator];

        _validOwner(_nftContract, _tokenId, _msgSender());

        uint256 marketFee = (offer.price * platformFee) / 10000;
        uint256 feeAmount = marketFee;

        offer.payToken.safeTransferFrom(_creator, feeReceipient, feeAmount);

        uint256 royaltyFee = 0;

        if (
            minters[_nftContract][_tokenId] != address(0) &&
            royalties[_nftContract][_tokenId] != 0
        ) {
            royaltyFee =
                ((offer.price - feeAmount) *
                    royalties[_nftContract][_tokenId]) /
                10000;
            offer.payToken.safeTransferFrom(
                _creator,
                minters[_nftContract][_tokenId],
                royaltyFee
            );
            feeAmount = feeAmount + royaltyFee;
        }

        offer.payToken.safeTransferFrom(
            _creator,
            _msgSender(),
            offer.price - feeAmount
        );

        // Transfer NFT to buyer
        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftContract).safeTransferFrom(
                _msgSender(),
                _creator,
                _tokenId
            );
        }

        emit ItemSold(
            _msgSender(),
            _creator,
            _nftContract,
            _tokenId,
            address(offer.payToken),
            offer.price,
            marketFee,
            royaltyFee
        );

        emit OfferCanceled(_creator, _nftContract, _tokenId);

        delete (listings[_nftContract][_tokenId][_msgSender()]);
        delete (offers[_nftContract][_tokenId][_creator]);
    }

    /**
     @notice Method for updating platform fee
     @dev Only admin
     @param _platformFee uint16 the platform fee to set
     */
    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient)
        external
        onlyOwner
    {
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    /**
     @notice Update FantomAddressRegistry contract
     @dev Only admin
     */
    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IFibboAddressRegistry(_registry);
    }

    function updateFibboVerification(address _verification) external onlyOwner {
        fibboVerification = IFibboVerification(_verification);
    }

    ////////////////////////////
    /// Internal and Private ///
    ////////////////////////////

    function _getNow() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _validPayToken(address _payToken) internal {
        require(
            _payToken == address(0) ||
                (addressRegistry.tokenRegistry() != address(0) &&
                    IFibboTokenRegistry(addressRegistry.tokenRegistry())
                        .enabled(_payToken)),
            "invalid pay token"
        );
    }

    function _validOwner(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) internal {
        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftContract);
            require(nft.ownerOf(_tokenId) == _owner, "not owning item");
        } else {
            revert("invalid nft address");
        }
    }

    function _cancelListing(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) private {
        Listing memory listedItem = listings[_nftContract][_tokenId][_owner];

        _validOwner(_nftContract, _tokenId, _owner);

        delete (listings[_nftContract][_tokenId][_owner]);
        emit ItemCanceled(_owner, _nftContract, _tokenId);
    }
}
