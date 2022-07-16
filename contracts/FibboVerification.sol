// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FibboVerification is OwnableUpgradeable {
    mapping(address => bool) verifiedArtists;

    mapping(address => bool) verifiedInversors;

    /// @notice Contract initializer
    function initialize() public initializer {
        __Ownable_init();
    }

    modifier isNotVerified(address _address) {
        bool verified = verifiedArtists[_address];
        require(!verified, "This address is already verified!");
        _;
    }

    modifier isNotVerifiedInversor(address _address) {
        bool verified = verifiedInversors[_address];
        require(!verified, "This address is already verified!");
        _;
    }

    modifier isVerified(address _address) {
        bool verified = verifiedArtists[_address];
        require(verified, "This address is not verified!");
        _;
    }

    modifier isVerifiedInversor(address _address) {
        bool verified = verifiedInversors[_address];
        require(verified, "This address is not verified!");
        _;
    }

    function verificateAddress(address _toVerificate)
        external
        isNotVerified(_toVerificate)
        onlyOwner
    {
        verifiedArtists[_toVerificate] = true;
    }

    function verificateInversor(address _toVerificate)
        external
        isNotVerifiedInversor(_toVerificate)
        onlyOwner
    {
        verifiedInversors[_toVerificate] = true;
    }

    function checkIfVerified(address _address) public view returns (bool) {
        return verifiedArtists[_address];
    }

    function checkIfVerifiedInversor(address _address)
        public
        view
        returns (bool)
    {
        return verifiedInversors[_address];
    }

    function unverifyAddress(address _toVerificate)
        external
        isVerified(_toVerificate)
        onlyOwner
    {
        delete verifiedArtists[_toVerificate];
    }

    function unverifyInversor(address _toVerificate)
        external
        isVerifiedInversor(_toVerificate)
        onlyOwner
    {
        delete verifiedInversors[_toVerificate];
    }
}
