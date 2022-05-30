// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FibboAddressRegistry is Ownable {
  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

  /// @notice Fibbo default Collection contract
  address public fibboCollection;

  /// @notice FibboMarketplace contract
  address public marketplace;

  /**
     @notice Update artion contract
     @dev Only admin
     */
  function updateFibboCollection(address _fibboCollection) external onlyOwner {
    require(
      IERC165(_fibboCollection).supportsInterface(INTERFACE_ID_ERC721),
      "Not ERC721"
    );
    fibboCollection = _fibboCollection;
  }

  /**
     @notice Update FantomMarketplace contract
     @dev Only admin
     */
  function updateMarketplace(address _marketplace) external onlyOwner {
    marketplace = _marketplace;
  }
}
