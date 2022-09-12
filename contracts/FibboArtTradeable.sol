// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);
}

/**
 * @title FibboArtTradeable
 * FibboArtTradeable - ERC721 contract that whitelists an operator address, 
 * has mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract FibboArtTradeable is ERC721, ERC2771Context {
    uint256 private _currentTokenID = 0;

    address private _owner;

    /// @notice Fibbo Address Verfification
    IFibboVerification public fibboVerification;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    //Mapping for freezed metadata
    mapping(uint256 => bool) private _freezedMetadata;

    mapping(uint256 => address) public creators;

    // Fibbo Marketplace contract
    address marketplace;

    // Fibbo contracts manager
    address contractsManager;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    address public minimalForwarder;

    constructor(
        string memory _name,
        string memory _symbol,
        address _marketplace,
        address _verification,
        address _contractsManager,
        address forwarder
    ) public ERC721(_name, _symbol) ERC2771Context(forwarder) {
        marketplace = _marketplace;
        fibboVerification = IFibboVerification(_verification);
        contractsManager = _contractsManager;
        minimalForwarder = forwarder;
        _owner = _msgSender();
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
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
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    modifier onlyCreator(uint256 _tokenId, address _requester) {
        address creator = creators[_tokenId];
        address currentOwner = ownerOf(_tokenId);
        require(
            creator == _requester || contractsManager == _requester,
            "Caller not allowed!"
        );
        _;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _checkOwner() internal view virtual {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
    }

    function uri(uint256 _id) public view returns (string memory) {
        require(_exists(_id), "ERC721Tradable#uri: NONEXISTENT_TOKEN");
        return _tokenURIs[_id];
    }

    /**
     * @dev Creates a new token
     * @param _to owner address of the new token
     * @param _uri Optional URI for this token type
     */
    function mint(address _to, string calldata _uri) public returns (uint256) {
        uint256 _id = _getNextTokenID();
        _incrementTokenId();

        creators[_id] = msg.sender;

        _mint(_to, _id);
        _setTokenURI(_id, _uri);
        setApprovalForAll(marketplace, true);

        return _id;
    }

    /**
     * @dev Burns an existing token
     * @param tokenId tokenId about to be burned
     */
    function burn(uint256 tokenId) public returns (uint256) {
        require(_exists(tokenId), "The token dont exist");

        address owner = ownerOf(tokenId);
        require(
            owner == _msgSender(),
            "You need to be the owner in order to burn!"
        );

        _burn(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );

        _transfer(from, to, tokenId);
    }

    /**
     * @dev External function to set the metadata freezed.
     * Reverts if the token ID does not exist.
     * @param _tokenId uint256 ID of the token to set its URI
     * @param _uri string URI to assign
     */
    function setFreezedMetadata(uint256 _tokenId, string memory _uri)
        external
        onlyCreator(_tokenId, msg.sender)
    {
        require(_exists(_tokenId), "setFreezedMetadata: Token should exist");
        _freezedMetadata[_tokenId] = true;
        _tokenURIs[_tokenId] = _uri;
    }

    function isFreezedMetadata(uint256 _tokenId) public view returns (bool) {
        return _freezedMetadata[_tokenId];
    }

    function setTokenUri(uint256 _tokenId, string memory _uri)
        external
        onlyCreator(_tokenId, msg.sender)
    {
        require(_exists(_tokenId), "setTokenUri: Token should exist");
        require(
            !isFreezedMetadata(_tokenId),
            "setTokenUri: Token has freezed metadata"
        );
        _tokenURIs[_tokenId] = _uri;
    }

    function getCurrentTokenID() public view returns (uint256) {
        return _currentTokenID;
    }

    /**
     * Override isApprovedForAll to whitelist Fantom contracts to enable gas-less listings.
     */
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // Whitelist Fantom marketplace, bundle marketplace contracts for easy trading.
        if (marketplace == _operator) {
            return true;
        }

        return ERC721.isApprovedForAll(_owner, _operator);
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function exists(uint256 _id) public view returns (bool) {
        return creators[_id] != address(0);
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenID
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    /**
     * @dev increments the value of _currentTokenID
     */
    function _incrementTokenId() private {
        _currentTokenID++;
    }

    /**
     * @dev Internal function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param _id uint256 ID of the token to set its URI
     * @param _uri string URI to assign
     */
    function _setTokenURI(uint256 _id, string memory _uri) internal {
        require(_exists(_id), "_setTokenURI: Token should exist");
        _tokenURIs[_id] = _uri;
    }

    function updateFibboVerification(address _verification) external {
        fibboVerification = IFibboVerification(_verification);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
