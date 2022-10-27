// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "erc721a@3.3.0/contracts/ERC721A.sol";
import "erc721a@3.3.0/contracts/extensions/ERC721ABurnable.sol";
import "erc721a@3.3.0/contracts/extensions/ERC721AQueryable.sol";

contract Morph is
    ERC721A("Morph", "MORPH"),
    ERC721AQueryable,
    ERC721ABurnable,
    ERC2981,
    Ownable,
    ReentrancyGuard
{
    // Whitelist Config
    bytes32 public whitelistMerkleRoot;
    uint256 public morphPriceWhitelist = 0 ether;
    uint256 public whitelistActiveTime = type(uint256).max;

    // Main Sale Config
    uint256 public morphPrice = 0.5 ether;
    uint256 public constant maxSupply = 1000;
    uint256 public saleActiveTime = type(uint256).max;
    string public imagesFolder;

    // Per Wallet Limit
    uint256 public maxMorphsPerWallet = 2;

    // Auto Approve Marketplaces
    mapping(address => bool) public approvedProxy;

    constructor() {
        _setDefaultRoyalty(msg.sender, 5_00); // 5.00%
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
    }

    /// @notice Purchase NFTs
    function purchaseMorphs(uint256 _qty) external payable nonReentrant {
        _safeMint(msg.sender, _qty);

        require(totalSupply() <= maxSupply, "Try mint less");
        require(tx.origin == msg.sender, "The caller is a contract");
        require(block.timestamp > saleActiveTime, "Sale is not active");
        require(
            msg.value == _qty * morphPrice,
            "Try to send exact amount of ETH"
        );
        require(
            _numberMinted(msg.sender) <= maxMorphsPerWallet,
            "Max morphs per wallet reached"
        );
    }

    /// @notice Owner can withdraw ETH from here
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /// @notice Change price in case of ETH price changes too much
    function setMorphPrice(uint256 _newMorphPrice) external onlyOwner {
        morphPrice = _newMorphPrice;
    }

    function setMaxMorphsPerWallet(uint256 _maxMorphsPerWallet)
        external
        onlyOwner
    {
        maxMorphsPerWallet = _maxMorphsPerWallet;
    }

    /// @notice set sale active time
    function setSaleActiveTime(uint256 _saleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
    }

    /// @notice Hide identity or show identity from here, put images folder here, ipfs folder cid
    function setImagesFolder(string memory __imagesFolder) external onlyOwner {
        imagesFolder = __imagesFolder;
    }

    /// @notice Send NFTs to a list of addresses
    function giftNft(address[] calldata _sendNftsTo, uint256 _qty)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _qty);
        require(totalSupply() <= maxSupply, "Try minting less");
    }

    //////////////////////
    // STANDARD METHODS //
    //////////////////////

    function _baseURI() internal view override returns (string memory) {
        return imagesFolder;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, IERC165, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        external
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    receive() external payable {}

    function receiveCoin() external payable {}

    ///////////////////////////////
    // AUTO APPROVE MARKETPLACES //
    ///////////////////////////////

    function autoApproveMarketplace(address _marketplace) public onlyOwner {
        approvedProxy[_marketplace] = !approvedProxy[_marketplace];
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override(ERC721A, IERC721)
        returns (bool)
    {
        return
            approvedProxy[_operator]
                ? true
                : super.isApprovedForAll(_owner, _operator);
    }

    ////////////////
    // Whitelist  //
    ////////////////

    function purchaseMorphsWhitelist(uint256 _qty, bytes32[] calldata _proof)
        external
        payable
        nonReentrant
    {
        _safeMint(msg.sender, _qty);

        require(totalSupply() <= maxSupply, "Try mint less");
        require(tx.origin == msg.sender, "The caller is a contract");
        require(inWhitelist(msg.sender, _proof), "You are not in whitelist");
        require(
            block.timestamp > whitelistActiveTime,
            "Whitelist is not active"
        );
        require(
            msg.value == _qty * morphPriceWhitelist,
            "Try to send exact amount of ETH"
        );
        require(
            _numberMinted(msg.sender) == 1,
            "Only 1 spot is available in whitelist"
        );
    }

    function inWhitelist(address _owner, bytes32[] memory _proof)
        public
        view
        returns (bool)
    {
        return
            MerkleProof.verify(
                _proof,
                whitelistMerkleRoot,
                keccak256(abi.encodePacked(_owner))
            );
    }

    function setWhitelistActiveTime(uint256 _whitelistActiveTime)
        external
        onlyOwner
    {
        whitelistActiveTime = _whitelistActiveTime;
    }

    function setWhitelistMorphPrice(uint256 _morphPriceWhitelist)
        external
        onlyOwner
    {
        morphPriceWhitelist = _morphPriceWhitelist;
    }

    function setWhitelist(bytes32 _whitelistMerkleRoot) external onlyOwner {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }
}
