// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FibboAddressRegistry is OwnableUpgradeable {
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

    /// @notice Fibbo default Collection contract
    address public fibboCollection;

    /// @notice FibboMarketplace contract
    address public marketplace;

    /// @notice FibboAuction contract
    address public auction;

    /// @notice FibboMarketplace contract
    address public community;

    /// @notice FibboMarketplace contract
    address public verification;

    /// @notice FibboTokenRegistry contract
    address public tokenRegistry;

    /// @notice Contract initializer
    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     @notice Update Fibbo default collection contract
     @dev Only admin
     */
    function updateFibboCollection(address _fibboCollection)
        external
        onlyOwner
    {
        require(
            IERC165(_fibboCollection).supportsInterface(INTERFACE_ID_ERC721),
            "Not ERC721"
        );
        fibboCollection = _fibboCollection;
    }

    /**
     @notice Update FibboMarket contract
     @dev Only admin
     */
    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    /**
     @notice Update FibboAuction contract
     @dev Only admin
     */
    function updateAuction(address _auction) external onlyOwner {
        auction = _auction;
    }

    /**
     @notice Update FibboTokenRegistry contract
     @dev Only admin
     */
    function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
        tokenRegistry = _tokenRegistry;
    }

    /**
     @notice Update FibboCommunity contract
     @dev Only admin
     */
    function updateCommunity(address _community) external onlyOwner {
        community = _community;
    }

    /**
     @notice Update FibboVerification contract
     @dev Only admin
     */

    function updateVerification(address _verification) external onlyOwner {
        verification = _verification;
    }
}
