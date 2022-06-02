// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFibboAddressRegistry {
    function fibboCollection() external view returns (address);

    function marketplace() external view returns (address);

    function community() external view returns (address);
}

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);
}

contract FibboMarketplace is Ownable, ReentrancyGuard {
    //using AddressUpgradeable for address payable;

    event ItemListed(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        uint256 price
    );
    event ItemSold(
        address indexed seller,
        address indexed buyer,
        address indexed nft,
        uint256 tokenId,
        uint256 price
    );
    event OfferCreated(
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 price
    );
    event OfferCanceled(
        address indexed creator,
        address indexed nft,
        uint256 tokenId
    );

    IFibboVerification fibboVerification;

    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /// @notice Platform fee
    uint16 public platformFee;
    /// @notice Platform fee receipient
    address payable public feeReceipient;
    /// @notice NftAddress -> Token ID -> Minter

    /// @notice Address registry
    IFibboAddressRegistry public addressRegistry;

    mapping(address => mapping(uint256 => address)) public minters;

    mapping(address => mapping(uint256 => uint16)) public royalties;

    /// @notice NftAddress -> Token ID -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public listings;

    /// @notice NftAddress -> Token ID -> Offerer -> Offer
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public offers;

    /// @notice Contract initializer
    constructor(address payable _feeRecipient, uint16 _platformFee) {
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;
    }

    modifier isListed(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) {
        uint256 listing = listings[_nftContract][_tokenId][_owner];
        require(listing > 0, "not listed item");
        _;
    }

     modifier isValidAddress(
        address _address,
    ) {
        bool isValidAddress = fibboVerification.checkIfVerified(address);
        require(isValidAddress, "Address is not verified");
        _;
    }

    modifier notListed(
        address _nftContract,
        uint256 _tokenId,
        address _owner
    ) {
        uint256 listing = listings[_nftContract][_tokenId][_owner];
        require(listing == 0, "already listed");
        _;
    }

    modifier offerExists(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) {
        uint256 offer = offers[_nftContract][_tokenId][_creator];
        require(offer > 0, "offer not exists or expired");
        _;
    }

    modifier offerNotExists(
        address _nftContract,
        uint256 _tokenId,
        address _creator
    ) {
        uint256 offer = offers[_nftContract][_tokenId][_creator];
        require(offer == 0, "offer already created");
        _;
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

    function registerRoyalty(
        address _minter,
        address _nftContract,
        uint256 _tokenId,
        uint16 _royalty
    ) external {
        minters[_nftContract][_tokenId] = _minter;
        royalties[_nftContract][_tokenId] = _royalty;
    }

    function listItem(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    )
        external
        isVerifiedAddress(msg.sender)
        notListed(_nftContract, _tokenId, msg.sender)
    {
        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftContract);
            require(
                nft.ownerOf(_tokenId) == msg.sender,
                "Sender don't own item!"
            );
            require(
                nft.isApprovedForAll(msg.sender, address(this)),
                "Item is not approved!"
            );
        } else {
            revert("Invalid nft contract!");
        }

        listings[_nftContract][_tokenId][msg.sender] = _price;

        emit ItemListed(msg.sender, _nftContract, _tokenId, _price);
    }

    /// @notice Method for canceling listed NFT
    function cancelListing(address _nftContract, uint256 _tokenId)
        external
        nonReentrant
        isListed(_nftContract, _tokenId, msg.sender)
        isValidAddress(msg.sender)
    {
        _validOwner(_nftContract, _tokenId, msg.sender);
        delete (listings[_nftContract][_tokenId][msg.sender]);
    }

    /// @notice Method for updating listed NFT
    /// @param _nftContract Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _newPrice New sale price for each iteam
    function updateListing(
        address _nftContract,
        uint256 _tokenId,
        uint256 _newPrice
    ) external nonReentrant  isListed(_nftContract, _tokenId, msg.sender) isValidAddress(msg.sender) {
        listings[_nftContract][_tokenId][msg.sender] = _newPrice;
    }

    function buyItem(
        address _nftContract,
        uint256 _tokenId,
        address payable _owner
    ) external payable nonReentrant isListed(_nftContract, _tokenId, _owner) {
        uint256 price = listings[_nftContract][_tokenId][_owner];

        require(msg.value >= price, "Not enough to buy item");

        uint256 feeAmount = (price * platformFee) / 10000;

        bool sentFee = feeReceipient.send(feeAmount);
        require(sentFee, "Transfer of ETH failed, fee payment");

        address minter = minters[_nftContract][_tokenId];
        uint16 royalty = royalties[_nftContract][_tokenId];

        if (minter != address(0) && royalty != 0) {
            uint256 royaltyFee = ((price - feeAmount) * royalty) / 10000;

            bool royaltySend = payable(minter).send(royaltyFee);
            require(royaltySend, "Transfer of ETH failed, royalty payment");

            feeAmount = feeAmount + royaltyFee;
        }

        bool sent = _owner.send(price - feeAmount);
        require(sent, "Transfer of FTM failed!");

        // Transfer NFT to buyer

        if (IERC165(_nftContract).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftContract).safeTransferFrom(
                _owner,
                msg.sender,
                _tokenId
            );
        }

        emit ItemSold(_owner, msg.sender, _nftContract, _tokenId, price);
        delete (listings[_nftContract][_tokenId][_owner]);
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
}
