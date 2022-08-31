// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);
}

/**
 * @title FibboArtTradeable
 * FibboArtTradeable - ERC721 contract that whitelists an operator address, 
 * has mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract FibboArtTradeable is ERC721, Ownable {
    uint256 private _currentTokenID = 0;

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

    constructor(
        string memory _name,
        string memory _symbol,
        address _marketplace,
        address _verification,
        address _contractsManager
    ) public ERC721(_name, _symbol) {
        marketplace = _marketplace;
        fibboVerification = IFibboVerification(_verification);
        contractsManager = _contractsManager;
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

    function updateFibboVerification(address _verification) external onlyOwner {
        fibboVerification = IFibboVerification(_verification);
    }
}
