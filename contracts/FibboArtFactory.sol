// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./FibboArtTradeable.sol";

contract FibboArtFactory is OwnableUpgradeable {
    /// @dev Events of the contract
    event ContractCreated(address creator, address nft);
    event ContractDisabled(address caller, address nft);

    /// @notice Fantom marketplace contract address;
    address public marketplace;

    /// @notice NFT Address => Bool
    mapping(address => bool) public exists;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    IFibboVerification fibboVerification;

    /// @notice Contract initializer
    function initialize(address _marketplace) public initializer {
        marketplace = _marketplace;

        __Ownable_init();
    }

    modifier isVerifiedAddress(address _address) {
        bool isValidAddress = fibboVerification.checkIfVerified(_address);
        require(isValidAddress, "Address is not verified");

        _;
    }

    /**
    @notice Update marketplace contract
    @dev Only admin
    @param _marketplace address the marketplace contract address to set
    */
    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    /// @notice Method for deploy new FantomArtTradable contract
    /// @param _name Name of NFT contract
    /// @param _symbol Symbol of NFT contract
    function createNFTContract(string memory _name, string memory _symbol)
        external
        payable
        isVerifiedAddress(msg.sender)
        returns (address)
    {
        FibboArtTradeable nft = new FibboArtTradeable(
            _name,
            _symbol,
            marketplace,
            address(fibboVerification),
            owner()
        );
        exists[address(nft)] = true;
        nft.transferOwnership(msg.sender);
        emit ContractCreated(msg.sender, address(nft));
        return address(nft);
    }

    /* /// @notice Method for registering existing FantomArtTradable contract
    /// @param  tokenContractAddress Address of NFT contract
    function registerTokenContract(address tokenContractAddress)
        external
        onlyOwner
    {
        require(
            !exists[tokenContractAddress],
            "Art contract already registered"
        );
        require(
            IERC165(tokenContractAddress).supportsInterface(
                INTERFACE_ID_ERC1155
            ),
            "Not an ERC1155 contract"
        );
        exists[tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), tokenContractAddress);
    }*/

    /// @notice Method for disabling existing FantomArtTradable contract
    /// @param  tokenContractAddress Address of NFT contract
    function disableTokenContract(address tokenContractAddress)
        external
        onlyOwner
    {
        require(exists[tokenContractAddress], "Art contract is not registered");
        exists[tokenContractAddress] = false;
        emit ContractDisabled(_msgSender(), tokenContractAddress);
    }

    function updateFibboVerification(address _verification) external onlyOwner {
        fibboVerification = IFibboVerification(_verification);
    }
}
