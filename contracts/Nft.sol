// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "erc721a/contracts/ERC721A.sol";
import {DefaultOperatorFilterer} from "https://github.com/ProjectOpenSea/operator-filter-registry/blob/main/src/DefaultOperatorFilterer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC4907A} from "https://raw.githubusercontent.com/umer-bigosoft/layerZero/master/contracts/ERC4907A.sol";

interface OpenSea {
    function proxies(address) external view returns (address);
}

contract CyberSyndicate is ERC4907A("CyberSyndicate", "CSE"), Ownable, ERC2981, DefaultOperatorFilterer {
    string public imagesLink;
    bool public revealed = false;
    uint256 public maxSupply = 5000;
    uint256 public reservedNfts = 50;
    uint256 public buyActiveTime = 0;
    uint256 public maxMintAmount = 10;
    string public notRevealedImagesLink;
    uint256 public nftPrice = 0.015 * 1e18;
    string constant baseExtension = ".json";

    constructor() {
        _setDefaultRoyalty(msg.sender, 500); // 5.00 %
    }

    // public
    function buyNft(uint256 _mintAmount) public payable {
        require(block.timestamp > buyActiveTime, "the contract is paused");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(_numberMinted(msg.sender) + _mintAmount <= maxMintAmount, "max mint amount per session exceeded");
        require(supply + _mintAmount + reservedNfts <= maxSupply, "max NFT limit exceeded");
        require(msg.value == nftPrice * _mintAmount, "insufficient funds");

        _safeMint(msg.sender, _mintAmount);
    }

    function numberMinted(address _address) public view returns (uint256) {
        return _numberMinted(_address);
    }

    ///////////////////////////////////
    //       OVERRIDE CODE STARTS    //
    ///////////////////////////////////

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC4907A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return imagesLink;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721A) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (revealed == false) return notRevealedImagesLink;

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, _toString(tokenId), baseExtension))
                : "";
    }

    //////////////////
    //  ONLY OWNER  //
    //////////////////

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    function airdropNft(address[] calldata _sendNftsTo, uint256 _howMany) external onlyOwner {
        reservedNfts -= _sendNftsTo.length * _howMany;

        for (uint256 i = 0; i < _sendNftsTo.length; i++) _safeMint(_sendNftsTo[i], _howMany);
    }

    function set_reservedNfts(uint256 _reservedNfts) public onlyOwner {
        reservedNfts = _reservedNfts;
    }

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function revealFlip() public onlyOwner {
        revealed = !revealed;
    }

    function set_nftPrice(uint256 _nftPrice) public onlyOwner {
        nftPrice = _nftPrice;
    }

    function setMaxMintAmount(uint256 _maxMintAmount) public onlyOwner {
        maxMintAmount = _maxMintAmount;
    }

    function set_imagesLink(string memory _imagesLink) public onlyOwner {
        imagesLink = _imagesLink;
    }

    function set_notRevealedImagesLink(string memory _notRevealedImagesLink) public onlyOwner {
        notRevealedImagesLink = _notRevealedImagesLink;
    }

    function set_buyActiveTime(uint256 _buyActiveTime) public onlyOwner {
        buyActiveTime = _buyActiveTime;
    }

    address public signer = msg.sender;

    function set_signer(uint256 _signer) public onlyOwner {
        signer = _signer;
    }
}

contract Nft is CyberSyndicate {
    // multiple presale configs
    mapping(bytes => bool) public _signatureUsed;
    mapping(uint256 => uint256) public maxMintPresales;
    mapping(uint256 => uint256) public itemPricePresales;
    uint256 public presaleActiveTime = type(uint256).max;

    function purchaseNft(
        uint256 _howMany,
        bytes32 _signedMessageHash,
        uint256 _rootNumber,
        bytes memory _signature
    ) external payable {
        require(block.timestamp > presaleActiveTime, "Presale is not active");
        require(_howMany > 0 && _howMany <= 10, "Invalid quantity of tokens to purchase");

        require(_signatureUsed[_signature] == false, "Signature is already used");

        require(msg.value == _howMany * itemPricePresales[_rootNumber], "Try to send more ETH");
        require(_numberMinted(msg.sender) + _howMany <= maxMintPresales[_rootNumber], "Purchase exceeds max allowed");

        require(_signature.length == 65, "Invalid signature length");
        address recoveredSigner = verifySignature(_signedMessageHash, _signature);
        require(recoveredSigner == signer, "Invalid signature");
        _signatureUsed[_signature] = true;
        _safeMint(msg.sender, _howMany);
    }

    // function to return the messageHash
    function messageHash(string memory _message) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _message));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    // verifySignature helper function
    function verifySignature(bytes32 _signedMessageHash, bytes memory _signature) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        require(_signature.length == 65, "Invalid signature length");

        // Divide the signature into its three components
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := and(mload(add(_signature, 65)), 255)
        }

        // Ensure the validity of v
        // Ensure the validity of v
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature v value");

        // Recover the signer's address
        address signer = ecrecover(_signedMessageHash, v, r, s);
        require(signer != address(0), "Invalid signature");

        return signer;
    }

    function setPresale(uint256 _rootNumber, uint256 _maxMintPresales, uint256 _itemPricePresale) external onlyOwner {
        maxMintPresales[_rootNumber] = _maxMintPresales;
        itemPricePresales[_rootNumber] = _itemPricePresale;
    }

    function setPresaleActiveTime(uint256 _presaleActiveTime) external onlyOwner {
        presaleActiveTime = _presaleActiveTime;
    }

    // implementing Operator Filter Registry
    // https://opensea.io/blog/announcements/on-creator-fees
    // https://github.com/ProjectOpenSea/operator-filter-registry#usage

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(
        address operator,
        uint256 tokenId
    ) public payable virtual override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable virtual override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}

contract CyberSyndicateContract is Nft {}
