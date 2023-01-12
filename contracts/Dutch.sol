// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

// imported smart contracts from openzepplin 
import "erc721a@4.2.3/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import {DefaultOperatorFilterer} from "https://github.com/ProjectOpenSea/operator-filter-registry/blob/main/src/DefaultOperatorFilterer.sol";

// NftPublicSale smart contract is inherited from ERC721a, Ownable, ERC2981 and implemented DefaultOperatorFilter from OpenSea
contract NftPublicSale is
    ERC721A("TechnoFeudal", "TF"),
    Ownable,
    ERC2981,
    DefaultOperatorFilterer
{
    // nftRevealed is boolean type variable that tells us that NFTs are revealed for the auction or not.
    bool public nftRevealed = false;
    // maximum supply of NFTs variable holdes the limit of NFTs supplied
    uint256 public maxNFTSupply = 10_000;
    // NFT minting fee will be maximum 20
    uint256 public maxNFTMintAmout = 20;
    // Owner owns the NFTs 
    uint256 public nftsForOwner = 250;
    // Maximum NFTs which is minted for Active sale
    uint256 public maxNftsMintForSale;
    // this variable holdes the link of IPFS for NFTs metadata
    string public metadataFolderIpfsLink;

    uint256 public nftPerAddressLimit = 3;
    string constant baseExtension = ".json";

    uint256 public costPerNft = 0.075 * 1e18;

    string public notRevealedMetadataFolderIpfsLink;
    // this variable holdes the active time for nft minting this will be 365 days onward from the first transaction occured

    uint256 public publicMintActiveTime = block.timestamp + 365 days; // gte value from https://www.epochconverter.com/
    // smart contract will runs once when the smart contract would be deployed 
    // this will set the royality for the ower on which address the smartcontract is deployed
    // this would be the 10% of the transaction

    constructor() {
        _setDefaultRoyalty(msg.sender, 10_00); // 10.00 %
    }

    // Public Sale function
    function purchaseTokens(uint256 _mintAmount) public payable {
        // this will check if the minting time is allowed and the contract is active 
        require(
            block.timestamp > publicMintActiveTime,
            "the contract is paused"
        );
        // supply variable will holdes the value of the total supply of NFTs
        uint256 supply = totalSupply();
        // this will check if there is NFTs available for acution or minted. if not this will restrict the transaction
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        // this will check the session minting amount limit. If the minting amount limit exceeds the allowd limit this will restrict the transaction
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxNFTMintAmout,
            "max mint amount per session exceeded"
        );
        // this will check if there is NFT limit is available 
        require(
            supply + _mintAmount + nftsForOwner <= maxNFTSupply,
            "max NFT limit exceeded"
        );
        // this will check if the minting limit that is applied on NFT minting is approached or not
        require(
            supply + _mintAmount + nftsForOwner <= maxNftsMintForSale,
            "Max Mint limit exceeded of this sale."
        );
        // this will check if there is enough balance available to execute this transaction
        require(msg.value >= costPerNft * _mintAmount, "insufficient funds");
        // if all the requrements satisfied safemint function will executes
        _safeMint(msg.sender, _mintAmount);
    }

    // this function will override the functionalites of the interfaces ERC721a and ERC2981 and will return the if the interfaces supports or not in boolean
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    // helper function to start the token 
    // Token ID start from 1
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
    // helper function to this will returns the IPFS link for the metadata used for NFTs
    // Base URI of IPFS metadata folder
    function _baseURI() internal view virtual override returns (string memory) {
        return metadataFolderIpfsLink;
    }


    // returns the URI of the NFTs Tokens 
    // Token URI of minted tokens
    // this function will override the functionalities of the ERC721a 
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        // this will check if the token ID exists or not 
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        // this will check if the NFT which is trying to access is revealed or not if not returns not revealed
        if (nftRevealed == false) return notRevealedMetadataFolderIpfsLink;

        string memory currentBaseURI = _baseURI();
        // this will retruns the URI for the token
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _toString(tokenId),
                        baseExtension
                    )
                )
                : "";
    }

    // Only owner can withdraw money
    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    // Only owner can set Minting amount for active sale
    // this will sets the limit on the NFTs which can be minted for sale
    function setMaxNFTsLimitForAuction(uint256 _maxMintForActiveSale)
        external
        onlyOwner
    {
        maxNftsMintForSale = _maxMintForActiveSale;
    }

    // Owner can gift NFTs to multiple addresses
    function giftNFT(address[] calldata _sendNftsTo, uint256 _howMany)
        external
        onlyOwner
    {
        nftsForOwner -= _sendNftsTo.length * _howMany;

        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _howMany);
    }

    //Owner can set Default Royalty
    // Royality works as at every time if an NFT is traded so percentage of the transaction will go to the minter who minted the NFT.
    // in our case it will be 10% of the transaction or price of the NFT
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Owner can reveal NFTs
    // if the NFT is not revealed it will reveal it or if already revealed it will reverse it
    function revealNftFlip() public onlyOwner {
        nftRevealed = !nftRevealed;
    }
    
    
    // Owner can set NFT per address limit
    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
        nftPerAddressLimit = _limit;
    }


    // Owner can set Per NFT cost
    function setCostPerNft(uint256 _newCostPerNft) public onlyOwner {
        costPerNft = _newCostPerNft;
    }

    // Owner can set max mint amount at once
    function setMaxMintAmount(uint256 _newMaxMintAmount) public onlyOwner {
        maxNFTMintAmout = _newMaxMintAmount;
    }

    // Owner can set Revealed NFTs IPFS metadata folder base URI
    function setMetadataFolderIpfsLink(string memory _newMetadataFolderIpfsLink)
        public
        onlyOwner
    {
        metadataFolderIpfsLink = _newMetadataFolderIpfsLink;
    }

    // Owner can set Non-Revealed NFTs IPFS metadata folder base URI
    function setNotRevealedMetadataFolderIpfsLink(
        string memory _notRevealedMetadataFolderIpfsLink
    ) public onlyOwner {
        notRevealedMetadataFolderIpfsLink = _notRevealedMetadataFolderIpfsLink;
    }

    // Owner can update sale start time
    function setSaleActiveTime(uint256 _publicMintActiveTime) public onlyOwner {
        publicMintActiveTime = _publicMintActiveTime;
    }

    // implementing Operator Filter Registry
    // https://opensea.io/blog/announcements/on-creator-fees
    // https://github.com/ProjectOpenSea/operator-filter-registry#usage

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        payable
        virtual
        override
        onlyAllowedOperatorApproval(operator)
    {
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

contract NftDutchAuctionSale is NftPublicSale {
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

    //Get NFT's Dutch Price
    function getDutchPrice() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startAt;
        uint256 timeBlocksPassed = timeElapsed / timeBlock;
        uint256 discount = discountRate * timeBlocksPassed;
        return
            discount >= startingPrice ? endingPrice : startingPrice - discount;
    }

    // Dutch Mint Public Function
    function dutchMint(uint256 _mintAmount) public payable {
        uint256 price = getDutchPrice();
        costPerNft = price / 2; // on each tx of dutch mint, update public sale price to half price of dutch price

        require(block.timestamp < expiresAt, "This auction has ended");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxNFTMintAmout,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + nftsForOwner <= maxNFTSupply,
            "max NFT limit exceeded"
        );
        require(
            supply + _mintAmount + nftsForOwner <= maxNftsMintForSale,
            "max NFT limit exceeded"
        );
        require(msg.value >= price * _mintAmount, "insufficient funds");

        uint256 refund = msg.value - price;
        if (refund > 0) payable(msg.sender).transfer(refund);
        _safeMint(msg.sender, _mintAmount);
    }

    // Owner can set Dutch NFTs starting price
    function setStartingPrice(uint256 _startingPrice) external onlyOwner {
        startingPrice = _startingPrice;
    }

    // Owner can set Dutch NFTs ending price
    function setEndingPrice(uint256 _endingPrice) external onlyOwner {
        endingPrice = _endingPrice;
    }

    // Owner can set Dutch NFTs Discounted price
    function setDiscountRate(uint256 _discountRate) external onlyOwner {
        discountRate = _discountRate;
    }

    // Owner can set Dutch Auction Start time
    function setStartAt(uint256 _startAt) external onlyOwner {
        startAt = _startAt;
    }

    // Owner can set Dutch Auction expiry time
    function setExpiresAt(uint256 _expiresAt) external onlyOwner {
        expiresAt = _expiresAt;
    }

    // Owner can set Dutch NFTs time block
    function setTimeBlock(uint256 _timeBlock) external onlyOwner {
        timeBlock = _timeBlock;
    }
}

contract NftAutoApproveMarketPlaces is NftDutchAuctionSale {
    mapping(address => bool) public projectProxy;

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
