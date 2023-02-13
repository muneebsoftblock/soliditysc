// SPDX-License-Identifier: MIT

//  TODO:
// sol version 0.8.18
// warnings, unused var
// withdraw, same contract
//
// dua, 80 20 in coding, can actually check from last year IA

pragma solidity 0.8.14;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract DigiCollect is
    ERC721A("Digi Collect Labs", "DCL"),
    Ownable,
    ERC721AQueryable,
    ERC2981
{
    /*
    










    put the variable correct values












    
    
    */

    // Variables
    uint256 public constant maxSupply = 10000;
    uint256 public reservedDigiCollect = 500;

    uint256 public maxDigiCollectPerWallet = 10;
    uint256 public digiCollectPrice = 0.01 ether;
    uint256 public saleActiveTime = type(uint256).max; // sale is closed by default

    string digiCollectImages;

    // these lines are called only once when the contract is deployed
    constructor() {
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
    }

    // Airdrop DigiCollect
    function giftDigiCollect(
        address[] calldata _sendNftsTo,
        uint256 _digiCollectQty
    )
        external
        onlyOwner
        digiCollectAvailable(_sendNftsTo.length * _digiCollectQty)
    {
        reservedDigiCollect -= _sendNftsTo.length * _digiCollectQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _digiCollectQty);
    }

    // buy / mint DigiCollect Nfts here
    function buyDigiCollect(uint256 _digiCollectQty)
        external
        payable
        callerIsUser
        saleActive(saleActiveTime)
        pricePaid(_digiCollectQty)
        digiCollectAvailable(_digiCollectQty)
        mintLimit(_digiCollectQty, maxDigiCollectPerWallet)
    {
        _mint(msg.sender, _digiCollectQty);
    }

    // withdraw eth
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // setters
    function setDigiCollectPrice(uint256 _digiCollectPrice) external onlyOwner {
        digiCollectPrice = _digiCollectPrice;
    }

    function setReservedDigiCollect(uint256 _reservedDigiCollect)
        external
        onlyOwner
    {
        reservedDigiCollect = _reservedDigiCollect;
    }

    function setMaxDigiCollectPerWallet(uint256 _maxDigiCollectPerWallet)
        external
        onlyOwner
    {
        maxDigiCollectPerWallet = _maxDigiCollectPerWallet;
    }

    function setSaleActiveTime(uint256 _saleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
    }

    function setDigiCollectImages(string memory _digiCollectImages)
        external
        onlyOwner
    {
        digiCollectImages = _digiCollectImages;
    }

    function setRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return digiCollectImages;
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

    // Helper Modifiers
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is a sm");
        _;
    }

    modifier saleActive(uint256 _saleActiveTime) {
        require(block.timestamp > _saleActiveTime, "Nope, sale is not open");
        _;
    }

    modifier mintLimit(
        uint256 _digiCollectQty,
        uint256 _maxDigiCollectPerWallet
    ) {
        require(
            _numberMinted(msg.sender) + _digiCollectQty <=
                _maxDigiCollectPerWallet,
            "DigiCollect max x wallet exceeded"
        );
        _;
    }

    modifier digiCollectAvailable(uint256 _digiCollectQty) {
        require(
            _digiCollectQty + totalSupply() + reservedDigiCollect <= maxSupply,
            "Currently are sold out"
        );
        _;
    }

    // Price Module:
    uint256 nftSoldPacketSize = 200;

    function set_nftSoldPacketSize(uint256 _nftSoldPacketSize)
        external
        onlyOwner
    {
        nftSoldPacketSize = _nftSoldPacketSize;
    }

    uint256 priceIncrease = 0.005 ether;

    function set_priceIncrease(uint256 _priceIncrease) external onlyOwner {
        priceIncrease = _priceIncrease;
    }

    function getPrice(uint256 _qty) public view returns (uint256 priceNow) {
        uint256 minted = totalSupply();

        uint256 packetsMinted = minted / nftSoldPacketSize; // getting benefit from dangerous calculation
        uint256 basePrice = digiCollectPrice * _qty;
        uint256 priceIncreaseForAll = packetsMinted * priceIncrease * _qty;
        priceNow = basePrice + priceIncreaseForAll;
    }

    modifier pricePaid(uint256 _digiCollectQty) {
        require(
            msg.value == getPrice(_digiCollectQty),
            "Hey hey, send the right amount of ETH"
        );
        _;
    }

    // DigiCollect Auto Approves Marketplaces
    mapping(address => bool) private allowed;

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override(ERC721A, IERC721)
        returns (bool)
    {
        if (allowed[_operator]) return true; // Opensea or any other Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}
