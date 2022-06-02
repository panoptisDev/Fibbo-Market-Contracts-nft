// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);
}

contract DefaultFibbo is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;
    address contractAddress;

    /// @notice Fibbo Address Verfification
    IFibboVerification public fibboVerification;

    modifier isVerifiedAddress(address _address) {
        bool verified = fibboVerification.checkIfVerified(_address);
        require(verified, "This address is not a verified artist!");
        _;
    }

    constructor(address marketplaceAddress)
        ERC721("Fibbo Default Collection", "FBODEF")
    {
        contractAddress = marketplaceAddress;
    }

    function createToken(string memory tokenURI)
        public
        isVerifiedAddress(msg.sender)
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(contractAddress, true);
        return newItemId;
    }

    function updateFibboVerification(address _verification) external onlyOwner {
        fibboVerification = IFibboVerification(_verification);
    }
}
