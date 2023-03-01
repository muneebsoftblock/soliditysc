// SPDX-License-Identifier: MIT

// getPrice warning

//
pragma solidity 0.8.14;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract LaziName is
    ERC721A("Lazi Name Service", "LNS"),
    Ownable,
    ERC721AQueryable,
    ERC2981
{
    // Variables
    uint256 public maxSupply = 10000;

    uint256 public laziNamePrice = 0.01 ether;
    uint256 public saleActiveTime = type(uint256).max;

    mapping(string => bool) public isMinted;
    mapping(uint256 => string) public domainNameOf;

    string laziNameImages;

    // these lines are called only once when the contract is deployed
    constructor() {
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
    }

    // Airdrop LaziName
    function airdrop(address[] calldata _addresses, string[] memory _laziNames)
        external
        onlyOwner
        laziNameAvailable(_laziNames.length)
    {
        for (uint256 i = 0; i < _laziNames.length; i++) {
            require(!isMinted[_laziNames[i]], "Nft Domain Already Minted");
            domainNameOf[totalSupply() + i] = _laziNames[i];
            _safeMint(_addresses[i], 1);
        }
    }

    function airdrop(address _address, string[] memory _laziNames)
        external
        onlyOwner
        laziNameAvailable(_laziNames.length)
    {
        for (uint256 i = 0; i < _laziNames.length; i++) {
            require(!isMinted[_laziNames[i]], "Nft Domain Already Minted");
            domainNameOf[totalSupply() + i] = _laziNames[i];
        }

        _safeMint(_address, _laziNames.length);
    }

    // buy LaziName Nfts
    function buyLaziNames(string[] memory _laziNames)
        external
        payable
        saleActive(saleActiveTime)
        pricePaid(_laziNames.length)
        laziNameAvailable(_laziNames.length)
    {
        for (uint256 i = 0; i < _laziNames.length; i++) {
            require(!isMinted[_laziNames[i]], "Nft Domain Already Minted");
            domainNameOf[totalSupply() + i] = _laziNames[i];
        }

        _safeMint(msg.sender, _laziNames.length);
    }

    // onlyOwner functions
    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    function set_maxSupply(uint256 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    function set_laziNamePrice(uint256 _laziNamePrice) external onlyOwner {
        laziNamePrice = _laziNamePrice;
    }

    function set_saleActiveTime(uint256 _saleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
    }

    function set_laziNameImages(string memory _laziNameImages)
        external
        onlyOwner
    {
        laziNameImages = _laziNameImages;
    }

    function set_royalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Helper Modifiers
    modifier saleActive(uint256 _saleActiveTime) {
        require(block.timestamp > _saleActiveTime, "Nope, sale is not open");
        _;
    }

    modifier laziNameAvailable(uint256 _laziNameQty) {
        require(
            _laziNameQty + totalSupply() <= maxSupply,
            "Currently are sold out"
        );
        _;
    }

    // Price Module
    uint256 public nftSoldPacketSize = 200;

    function set_nftSoldPacketSize(uint256 _nftSoldPacketSize)
        external
        onlyOwner
    {
        nftSoldPacketSize = _nftSoldPacketSize;
    }

    uint256 public priceIncrease = 0.005 ether;

    function set_priceIncrease(uint256 _priceIncrease) external onlyOwner {
        priceIncrease = _priceIncrease;
    }

    function getPrice(uint256 _qty) public view returns (uint256 priceNow) {
        uint256 minted = totalSupply();
        uint256 packetsMinted = minted / nftSoldPacketSize; // getting benefit from dangerous calculation
        uint256 basePrice = laziNamePrice * _qty;
        uint256 priceIncreaseForAll = packetsMinted * priceIncrease * _qty;
        priceNow = basePrice + priceIncreaseForAll;
    }

    modifier pricePaid(uint256 _qty) {
        require(
            msg.value == getPrice(_qty),
            "Hey hey, send the right amount of ETH"
        );
        _;
    }

    // LaziName Auto Approves Marketplaces
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

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return laziNameImages;
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
}
