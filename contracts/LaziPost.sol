// SPDX-License-Identifier: MIT

// getPrice warning

//
pragma solidity 0.8.14;

import "./LaziPostFactory.sol";

// For Remix
// import "erc721a@3.3.0/contracts/ERC721A.sol";
// import "erc721a@3.3.0/contracts/extensions/ERC721AQueryable.sol";

// For Truffle
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract LaziPost is ERC721A("Lazi Post", "LP"), Ownable, ERC721AQueryable, ReentrancyGuard, ERC2981 {
    using ECDSA for bytes32;

    mapping(bytes => bool) public signatureUsed;
    mapping(address => bool) private allowedSpender;
    LaziPostFactory public factory = LaziPostFactory(msg.sender);

    // these lines are called only once when the contract is deployed
    constructor() {
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
    }

    // Airdrop LaziPost
    function airdrop(address[] calldata _addresses, uint256[] calldata _counts) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            _mint(_addresses[i], _counts[i]);
        }
    }

    function buyNftSigned(
        uint256 _tokenId,
        address _seller,
        uint256 _price,
        uint256 _timestamp,
        bytes memory _signature
    ) external payable nonReentrant {
        // verify that correct data came from API
        bytes32 message = keccak256(abi.encodePacked(_seller, _price, _timestamp));
        require(factory.API_ADDRESS() == message.toEthSignedMessageHash().recover(_signature), "Invalid Signature");
        require(signatureUsed[_signature] == false, "Signature is already used");
        signatureUsed[_signature] = true;

        // Remaining conditions
        require(msg.value == _price, "Incorrect payment amount");
        require(_seller != msg.sender, "Seller and buyer must be different");

        // Transfer the price to the seller
        uint royaltyAmount = (_price * factory.royalty()) / 1.00 ether;
        if (royaltyAmount > 0) {
            (bool successRoyalty, ) = payable(factory.owner()).call{value: royaltyAmount}("");
            require(successRoyalty);
        }
        (bool successPayment, ) = payable(_seller).call{value: _price - royaltyAmount}("");
        require(successPayment);

        // Transfer the product to the buyer
        address buyer = msg.sender;

        if (_exists(_tokenId)) safeTransferFrom(_seller, buyer, _tokenId);
        else _mint(buyer, 1);
    }

    // onlyOwner functions
    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    function set_royaltyOpenSea(address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return string(abi.encodePacked(factory.laziPostImages(), abi.encodePacked(address(this)), "/"));
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC721A, ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowedSpender[_spender] = !allowedSpender[_spender];
    }

    function isApprovedForAll(address _owner, address _operator) public view override(IERC721A, ERC721A) returns (bool) {
        if (allowedSpender[_operator]) return true; // Opensea or any other Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}
