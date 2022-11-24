// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "erc721a/contracts/ERC721A.sol";
// import "erc721a@4.2.3/contracts/ERC721A.sol";
// import {DefaultOperatorFilterer} from "https://github.com/ProjectOpenSea/operator-filter-registry/blob/main/src/DefaultOperatorFilterer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface OpenSea {
    function proxies(address) external view returns (address);
}

contract Sample is
    ERC721A("Sample", "NTO"),
    Ownable,
    // DefaultOperatorFilterer,
    ERC2981
{
    bool public revealed = false;
    string public notRevealedMetadataFolderIpfsLink;
    uint256 public maxMintAmount = 10;
    uint256 public maxSupply = 5000;
    uint256 public costPerNft = 0.015 * 1e18;
    uint256 public nftsForOwner = 50;
    string public metadataFolderIpfsLink;
    uint256 constant presaleSupply = 300;
    string constant baseExtension = ".json";
    uint256 public publicmintActiveTime = 0;

    uint256 public claimSpotsSold = 0;
    uint256 public claimSpotsToSell = 5000;
    uint256 public maxMintClaimSpotAmount = 10;
    mapping(address => uint256) public claimSpotsBoughtBy;
    event PurchasedClaimSpot(address, uint256);

    uint256 public totalClaimSpotsSold;
    uint256 public claimSpotMintActiveTime = 0;

    constructor() {
        _setDefaultRoyalty(msg.sender, 500); // 5.00 %
    }

    function purchaseTokens(uint256 _mintAmount) external payable {
        require(
            block.timestamp > publicmintActiveTime,
            "the contract is paused"
        );
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + nftsForOwner + totalClaimSpotsSold <=
                maxSupply,
            "max NFT limit exceeded"
        );
        require(msg.value == costPerNft * _mintAmount, "insufficient funds");

        _safeMint(msg.sender, _mintAmount);
    }

    function purchaseClaimSpot(uint256 _mintAmount) external payable {
        require(_mintAmount > 0, "need to mint at least 1 spot");
        require(msg.value == costPerNft * _mintAmount, "incorrect funds");
        require(
            block.timestamp > claimSpotMintActiveTime,
            "The Claim Spot Mint is paused"
        );
        require(
            claimSpotsBoughtBy[msg.sender] + _mintAmount <=
                maxMintClaimSpotAmount,
            "max mint amount per session exceeded"
        );
        require(
            claimSpotsSold + _mintAmount <= claimSpotsToSell,
            "max mint amount per session exceeded"
        );

        claimSpotsBoughtBy[msg.sender] += _mintAmount;
        claimSpotsSold += _mintAmount;

        emit PurchasedClaimSpot(msg.sender, _mintAmount);
    }

    ///////////////////////////////////
    //       OVERRIDE CODE STARTS    //
    ///////////////////////////////////

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return metadataFolderIpfsLink;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) return notRevealedMetadataFolderIpfsLink;

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        "_toString(tokenId)",
                        baseExtension
                    )
                )
                : "";
    }

    //////////////////
    //  ONLY OWNER  //
    //////////////////

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    function giftNft(address[] calldata _sendNftsTo, uint256 _howMany)
        external
        onlyOwner
    {
        nftsForOwner -= _sendNftsTo.length * _howMany;

        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _howMany);
    }

    function setnftsForOwner(uint256 _newnftsForOwner) public onlyOwner {
        nftsForOwner = _newnftsForOwner;
    }

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function revealFlip() public onlyOwner {
        revealed = !revealed;
    }

    function setCostPerNft(uint256 _newCostPerNft) public onlyOwner {
        costPerNft = _newCostPerNft;
    }

    function setMaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setMetadataFolderIpfsLink(string memory _newMetadataFolderIpfsLink)
        public
        onlyOwner
    {
        metadataFolderIpfsLink = _newMetadataFolderIpfsLink;
    }

    function setNotRevealedMetadataFolderIpfsLink(
        string memory _notRevealedMetadataFolderIpfsLink
    ) public onlyOwner {
        notRevealedMetadataFolderIpfsLink = _notRevealedMetadataFolderIpfsLink;
    }

    function setSaleActiveTime(uint256 _publicmintActiveTime) public onlyOwner {
        publicmintActiveTime = _publicmintActiveTime;
    }
}

contract NftWhitelistClaimMerkle is Sample {
    ///////////////////////////////
    //      CLAIM CODE STARTS    //
    ///////////////////////////////

    // multiple claim list
    // 1 claim available => encoded list 1
    // 2 claim available => encoded list 2
    // 3 claim available => encoded list 3
    // ...
    mapping(uint256 => bytes32) public claimList;

    uint256 public claimActiveTime = type(uint256).max;

    function _inWhitelist(
        address _owner,
        bytes32[] memory _proof,
        uint256 _rootNumber
    ) private view returns (bool) {
        return
            MerkleProof.verify(
                _proof,
                claimList[_rootNumber],
                keccak256(abi.encodePacked(_owner))
            );
    }

    function claimNft(uint256 _howMany, bytes32[] calldata _proof)
        external
        payable
    {
        require(
            totalSupply() + _howMany + nftsForOwner <= maxSupply,
            "Max NFT limit exceeded"
        );
        require(
            _inWhitelist(msg.sender, _proof, _howMany),
            "You are not in claim list"
        );
        require(block.timestamp > claimActiveTime, "Claim is not active");
        require(_getAux(msg.sender) == 0, "Already claimed"); // 0 = Claim Available
        _safeMint(msg.sender, _howMany);
        _setAux(msg.sender, 1); // 1 = Claim Used
    }

    function setPresale(uint256 _rootNumber, bytes32 _claimList)
        external
        onlyOwner
    {
        claimList[_rootNumber] = _claimList;
    }

    function setClaimActiveTime(
        uint256 _startTime,
        uint256 _totalClaimSpotsSold
    ) external onlyOwner {
        claimActiveTime = _startTime;
        totalClaimSpotsSold = _totalClaimSpotsSold;
    }

    // implementing Operator Filter Registry
    // https://opensea.io/blog/announcements/on-creator-fees
    // https://github.com/ProjectOpenSea/operator-filter-registry#usage

    // function setApprovalForAll(address operator, bool approved)
    //     public
    //     virtual
    //     override
    //     onlyAllowedOperatorApproval(operator)
    // {
    //     super.setApprovalForAll(operator, approved);
    // }

    // function approve(address operator, uint256 tokenId)
    //     public
    //     payable
    //     virtual
    //     override
    //     onlyAllowedOperatorApproval(operator)
    // {
    //     super.approve(operator, tokenId);
    // }

    // function transferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public payable virtual override onlyAllowedOperator(from) {
    //     super.transferFrom(from, to, tokenId);
    // }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public payable virtual override onlyAllowedOperator(from) {
    //     super.safeTransferFrom(from, to, tokenId);
    // }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) public payable virtual override onlyAllowedOperator(from) {
    //     super.safeTransferFrom(from, to, tokenId, data);
    // }
}

contract SampleContract is NftWhitelistClaimMerkle {}
