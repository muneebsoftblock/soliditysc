// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

contract NftPublicSale is
    ERC721A("TechnoFeudal", "TF"),
    ERC721AQueryable,
    Ownable,
    ERC721ABurnable,
    ERC2981
{
    using Strings for uint256;

    bool public revealed = false;
    string public notRevealedMetadataFolderIpfsLink;
    uint256 public maxMintAmount = 20;
    uint256 public maxSupply = 10_000;
    uint256 public costPerNft = 0.075 * 1e18;
    uint256 public nftsForOwner = 250;
    string public metadataFolderIpfsLink;
    uint256 constant presaleSupply = 400;
    uint256 public nftPerAddressLimit = 3;
    string constant baseExtension = ".json";
    uint256 public publicmintActiveTime = block.timestamp + 365 days; // https://www.epochconverter.com/

    constructor() {
        _setDefaultRoyalty(msg.sender, 10_00); // 10.00 %
    }

    // public
    function purchaseTokens(uint256 _mintAmount) public payable {
        require(
            block.timestamp > publicmintActiveTime,
            "the contract is paused"
        );
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + nftsForOwner <= maxSupply,
            "max NFT limit exceeded"
        );
        require(msg.value >= costPerNft * _mintAmount, "insufficient funds");

        _safeMint(msg.sender, _mintAmount);
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

    function burn(uint256 tokenId) public override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
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
        override
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
                        tokenId.toString(),
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

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function revealFlip() public onlyOwner {
        revealed = !revealed;
    }

    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
        nftPerAddressLimit = _limit;
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

contract NftWhitelistSale is NftPublicSale {
    ///////////////////////////////
    //    PRESALE CODE STARTS    //
    ///////////////////////////////

    uint256 public presaleActiveTime = block.timestamp + 365 days; // https://www.epochconverter.com/;
    uint256 public presaleMaxMint = 3;
    uint256 public itemPricePresale = 0.03 * 1e18;
    mapping(address => uint256) public presaleClaimedBy;
    mapping(address => bool) public onPresale;

    function addToPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++)
            onPresale[addresses[i]] = true;
    }

    function removeFromPresale(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++)
            onPresale[addresses[i]] = false;
    }

    function purchaseTokensPresale(uint256 _howMany) external payable {
        uint256 supply = totalSupply();
        require(supply <= presaleSupply, "presale limit reached");
        require(
            supply + _howMany + nftsForOwner <= maxSupply,
            "max NFT limit exceeded"
        );

        require(onPresale[msg.sender], "You are not in presale");
        require(block.timestamp > presaleActiveTime, "Presale is not active");
        require(
            msg.value >= _howMany * itemPricePresale,
            "Try to send more ETH"
        );

        presaleClaimedBy[msg.sender] += _howMany;

        require(
            presaleClaimedBy[msg.sender] <= presaleMaxMint,
            "Purchase exceeds max allowed"
        );

        _safeMint(msg.sender, _howMany);
    }

    // set limit of presale
    function setPresaleMaxMint(uint256 _presaleMaxMint) external onlyOwner {
        presaleMaxMint = _presaleMaxMint;
    }

    // Change presale price in case of ETH price changes too much
    function setPricePresale(uint256 _itemPricePresale) external onlyOwner {
        itemPricePresale = _itemPricePresale;
    }

    function setPresaleActiveTime(uint256 _presaleActiveTime)
        external
        onlyOwner
    {
        presaleActiveTime = _presaleActiveTime;
    }
}

contract NftDutchAuctionSale is NftWhitelistSale {
    // Dutch Auction

    // immutable means you can not change value of this
    /*
    Dutch auction feature in the smart contract. Starting price will be 1eth and decrease by .05eth every 30 minutes until it reaches the price of .1eth.

    Whitelist will activate after public sale. Users should be able to purchase at 50% off of the final Dutch auction sale.
    */
    uint256 public startingPrice = 1 ether;
    uint256 public endingPrice = 0.1 ether;
    uint256 public discountRate = 0.05 ether;
    uint256 public startAt = type(uint256).max; // auction will not start automatically after deploying of contract
    uint256 public expiresAt = 0; //  auction will not start automatically after deploying of contract
    uint256 public timeBlock = 30 minutes; // prices decreases every 30 minutes

    function getDutchPrice() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startAt;
        uint256 timeBlocksPassed = timeElapsed / timeBlock;
        uint256 discount = discountRate * timeBlocksPassed;
        return
            discount >= startingPrice ? endingPrice : startingPrice - discount;
    }

    // public
    function dutchMint(uint256 _mintAmount) public payable {
        uint256 price = getDutchPrice();
        costPerNft = price / 2;
        itemPricePresale = price / 2;

        require(block.timestamp < expiresAt, "This auction has ended");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + nftsForOwner <= maxSupply,
            "max NFT limit exceeded"
        );
        require(msg.value >= price * _mintAmount, "insufficient funds");

        uint256 refund = msg.value - price;
        if (refund > 0) payable(msg.sender).transfer(refund);
        _safeMint(msg.sender, _mintAmount);
    }

    function setStartingPrice(uint256 _startingPrice) external onlyOwner {
        startingPrice = _startingPrice;
    }

    function setEndingPrice(uint256 _endingPrice) external onlyOwner {
        endingPrice = _endingPrice;
    }

    function setDiscountRate(uint256 _discountRate) external onlyOwner {
        discountRate = _discountRate;
    }

    function setStartAt(uint256 _startAt) external onlyOwner {
        startAt = _startAt;
    }

    function setExpiresAt(uint256 _expiresAt) external onlyOwner {
        expiresAt = _expiresAt;
    }

    function setTimeBlock(uint256 _timeBlock) external onlyOwner {
        timeBlock = _timeBlock;
    }
}

contract NftAutoApproveMarketPlaces is NftDutchAuctionSale {
    ////////////////////////////////
    // AUTO APPROVE MARKETPLACES  //
    ////////////////////////////////

    mapping(address => bool) public projectProxy; // check public vs private vs internal gas

    function flipProxyState(address proxyAddress) public onlyOwner {
        projectProxy[proxyAddress] = !projectProxy[proxyAddress];
    }

    // set auto approve for trusted marketplaces here
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        if (projectProxy[_operator]) return true; // ANY OTHER Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}

contract Nft is NftAutoApproveMarketPlaces {}
