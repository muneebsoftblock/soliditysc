// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "erc721a@4.2.3/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import {DefaultOperatorFilterer} from "https://github.com/ProjectOpenSea/operator-filter-registry/blob/main/src/DefaultOperatorFilterer.sol";

/// @title This is NFT smart contract
/// @author Shinning Star from Metaverse
/// @notice You can use this contract for minitng NFTs
/// @dev All function calls are currently implemented without side effects

contract MintingNFTsContract is
    ERC721A("TechnoFeudal", "TF"),
    Ownable,
    ERC2981,
    DefaultOperatorFilterer
{
    /// @dev By default revealCollection NFTs is false
    bool public revealCollection = false;
    /// @dev The total supply of NFT is 10000 set by developer
    uint256 public maxSupply = 10_000;
    /// @dev Max mint amount is 20
    uint256 public maxMintAmount = 20;
    /// @dev By default reserved NFTs for owner is 250
    uint256 public reservedNFTs = 250;
    /// @dev Per wallet address limit is 3 set by developer
    uint256 public perWalletLimit = 3;
    /// @dev Cost per NFT set by developer is 0.075ETH
    uint256 public NFTcost = 0.075 * 1e18;
    /// @dev Get value from https://www.epochconverter.com/
    uint256 public startSaleTime = block.timestamp + 365 days;
    /// @dev Base extention of NFTs is json format
    string constant baseExtension = ".json";
    uint256 public maxMintPerSale;
    string public metadataURL;
    string public beforeRevealURL;

    constructor() {
        /// @dev By default 10% Royalty will send to owner
        _setDefaultRoyalty(msg.sender, 10_00); // 10.00 %
    }

    /// @notice Public Sale Function to purchase NFTs
    function buyNFTs(uint256 _mintAmount) public payable {
        require(block.timestamp > startSaleTime, "the contract is paused");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + reservedNFTs <= maxSupply,
            "max NFT limit exceeded"
        );
        require(
            supply + _mintAmount + reservedNFTs <= maxMintPerSale,
            "Max Mint limit exceeded of this sale."
        );
        require(msg.value >= NFTcost * _mintAmount, "insufficient funds");
        /// @param:msg.sender will get caller address
        /// @param:_mintAmount will get how much NFTs caller wants to mint
        _safeMint(msg.sender, _mintAmount);
    }

    /// @dev This function override interfaces of different marketplaces
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Token ID start from 1
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @dev Base URI of IPFS metadata folder
    function _baseURI() internal view virtual override returns (string memory) {
        return metadataURL;
    }

    /// @dev This funciton will return minted token URI
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

        if (revealCollection == false) return beforeRevealURL;

        string memory currentBaseURI = _baseURI();
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

    /// @notice Only owner can withdraw money
    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    /* @notice Only owner can set Minting amount for active sale
     * @param: _maxMintForActiveSale Owner will pass max mint amount for current active sale
     */
    function setPerSaleMintableNFTs(uint256 _maxMintForActiveSale)
        external
        onlyOwner
    {
        maxMintPerSale = _maxMintForActiveSale;
    }

    /* @notice Owner can gift NFTs to multiple addresses
     * @param:_sendNftsTo Owner will pass list of address for gift NFTs
     * @param:_howMany Owner will be able to send multiple NFTs at once
     */
    function sendNFTsToWhitelistAddresses(
        address[] calldata _sendNftsTo,
        uint256 _howMany
    ) external onlyOwner {
        reservedNFTs -= _sendNftsTo.length * _howMany;

        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _howMany);
    }

    /* @notice Owner can set Default Royalty
     * @param: _receiver Owner will pass reciever address
     * @param: _feeNumerator Owner will pass numerator fee
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /// @notice Owner can reveal NFTs
    function setDisplayCollection() public onlyOwner {
        revealCollection = !revealCollection;
    }

    /* @notice Owner can set NFT per address limit
     * @param:_limit Owner will pass per wallet limit
     */
    function setPerWalletLimit(uint256 _limit) public onlyOwner {
        perWalletLimit = _limit;
    }

    /* @notice Owner can set Per NFT cost
     * @param: _newCostPerNft Owner will pass new cost of NFT
     */
    function setNFTPrice(uint256 _newCostPerNft) public onlyOwner {
        NFTcost = _newCostPerNft;
    }

    /* @notice Owner can set max mint amount at once during current sale
     * @param: _newMaxMintAmount Owner will pass new amount
     */
    function setMaxMintQuantity(uint256 _newMaxMintAmount) public onlyOwner {
        maxMintAmount = _newMaxMintAmount;
    }

    /* @notice Owner can set Revealed NFTs IPFS metadata folder base URI
     * @param: _newMetadataFolderIpfsLink Only owner can pass revealed NFTs metadata base URI
     */
    function setRevealCollectionURL(string memory _newMetadataFolderIpfsLink)
        public
        onlyOwner
    {
        metadataURL = _newMetadataFolderIpfsLink;
    }

    /* @notice Owner can set Non-Revealed NFTs IPFS metadata folder base URI
     * @param: _notRevealedMetadataFolderIpfsLink Owner will pass non Revealed base URI
     */
    function setNotRevealCollectionURL(
        string memory _notRevealedMetadataFolderIpfsLink
    ) public onlyOwner {
        beforeRevealURL = _notRevealedMetadataFolderIpfsLink;
    }

    /* @notice Owner can update sale start time
     * @param: _publicMintActiveTime Owner will pass public mint active time in epoch format
     */
    function setPublicSaleTime(uint256 _publicMintActiveTime) public onlyOwner {
        startSaleTime = _publicMintActiveTime;
    }

    /// @dev implementing Operator Filter Registry
    /// @dev https://opensea.io/blog/announcements/on-creator-fees
    /// @dev https://github.com/ProjectOpenSea/operator-filter-registry#usage

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

/* @title Dutch Auction
 * @author Shinning Star from Metaverse
 * @notice Dutch auction feature in the smart contract. Starting price will be 1eth and decrease by .05eth every 30 minutes until it reaches the price of .1eth.
 * @notice will activate after public sale. Users should be able to purchase at 50% off of the final Dutch auction sale.
 */
contract NftDutchAuctionSale is MintingNFTsContract {
    uint256 public startingPrice = 1 ether;
    uint256 public finalPrice = 0.1 ether;
    uint256 public discountRate = 0.05 ether;
    /// @dev Auction will not start automatically after deploying of contract
    uint256 public startAt = type(uint256).max;
    uint256 public expiresAt = 0;
    /// @dev Prices decreases every 30 minutes
    uint256 public timeBlock = 30 minutes;

    /// @dev Get NFT's Dutch Price
    /// @return This function will return discount price
    function getCurrentNFTPrice() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startAt;
        uint256 timeBlocksPassed = timeElapsed / timeBlock;
        uint256 discount = discountRate * timeBlocksPassed;
        return
            discount >= startingPrice ? finalPrice : startingPrice - discount;
    }

    /* @notice Dutch Mint Public Function
     * @param:_mintAmount Caller will pass minting NFTs amount
     */
    function dutchMint(uint256 _mintAmount) public payable {
        uint256 price = getCurrentNFTPrice();
        NFTcost = price / 2; // on each tx of dutch mint, update public sale price to half price of dutch price

        require(block.timestamp < expiresAt, "This auction has ended");
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _numberMinted(msg.sender) + _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(
            supply + _mintAmount + reservedNFTs <= maxSupply,
            "max NFT limit exceeded"
        );
        require(
            supply + _mintAmount + reservedNFTs <= maxMintPerSale,
            "max NFT limit exceeded"
        );
        require(msg.value >= price * _mintAmount, "insufficient funds");

        uint256 refund = msg.value - price;
        if (refund > 0) payable(msg.sender).transfer(refund);
        _safeMint(msg.sender, _mintAmount);
    }

    /* @notice Owner can set Dutch NFTs starting price
     * @param:_InitialPrice Owner will pass starting price
     */
    function setInitialPrice(uint256 _InitialPrice) external onlyOwner {
        startingPrice = _InitialPrice;
    }

    /* @notice Owner can set Dutch NFTs ending price
     * @param:_finalPrice Owner will pass ending price
     */
    function setFinalPrice(uint256 _finalPrice) external onlyOwner {
        finalPrice = _finalPrice;
    }

    /// @notice Owner can set Dutch NFTs Discounted price
    /// param:_discountRate Owner will pass discounted price
    function setDiscountRate(uint256 _discountRate) external onlyOwner {
        discountRate = _discountRate;
    }

    /* @notice Owner can set Dutch Auction Start time
     * @param:_startAt Owner will pass start time in epoch format
     */
    function setAuctionStartTime(uint256 _startAt) external onlyOwner {
        startAt = _startAt;
    }

    /* @notice Owner can set Dutch Auction expiry time
     * @param:_expiryTime Owner will pass end time in epoch format
     */
    function setAuctionEndTime(uint256 _expiryTime) external onlyOwner {
        expiresAt = _expiryTime;
    }

    // @notice Owner can set Dutch NFTs time block
    // @param:_timeBlock Owner will pass time block
    function setTimeBlock(uint256 _timeBlock) external onlyOwner {
        timeBlock = _timeBlock;
    }
}

contract NftAutoApproveMarketPlaces is NftDutchAuctionSale {
    mapping(address => bool) public projectProxy;

    function flipProxyState(address proxyAddress) public onlyOwner {
        projectProxy[proxyAddress] = !projectProxy[proxyAddress];
    }

    /// @dev set auto approve for trusted marketplaces here
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        /// @dev Any Other Marketplace
        if (projectProxy[_operator]) return true;
        return super.isApprovedForAll(_owner, _operator);
    }
}

contract Nft is NftAutoApproveMarketPlaces {}
