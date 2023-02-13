// SPDX-License-Identifier: MIT

// TODO: update to latest way
// withdraw
// getPrice warning

//
pragma solidity 0.8.14;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract LaziName is
    ERC721A("Lazi Name Service", "LNS"),
    Ownable,
    ERC721AQueryable,
    ERC721ABurnable,
    ERC2981
{
    // Variables
    uint256 public constant maxSupply = 10000;
    uint256 public reservedLaziName = 500;

    uint256 public freeLaziName = 0;
    uint256 public freeMaxLaziNamePerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public firstFreeMints = 1;
    uint256 public maxLaziNamePerWallet = 2;
    uint256 public laziNamePrice = 0.01 ether;
    uint256 public saleActiveTime = type(uint256).max;

    mapping(string => bool) public minted;
    mapping(uint256 => string) public domainNameOf;

    string laziNameMetadataURI;

    // these lines are called only once when the contract is deployed
    constructor() {
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
    }

    // Airdrop LaziName
    function giftLaziName(address[] calldata _sendNftsTo, uint256 _laziNameQty)
        external
        onlyOwner
        laziNameAvailable(_sendNftsTo.length * _laziNameQty)
    {
        reservedLaziName -= _sendNftsTo.length * _laziNameQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _laziNameQty);
    }

    // buy / mint LaziName Nfts here
    function buyLaziName(string memory _laziName)
        external
        payable
        saleActive(saleActiveTime)
        callerIsUser
        mintLimit(1, maxLaziNamePerWallet)
        priceAvailableFirstNftFree(1)
        laziNameAvailable(1)
    {
        require(_totalMinted() >= freeLaziName, "Get your LaziName for free");
        require(!minted[_laziName], "Nft Domain Already Minted");

        domainNameOf[totalSupply()] = _laziName;
        _mint(msg.sender, 1);
    }

    function buyLaziNameFree(uint256 _laziNameQty)
        external
        saleActive(freeSaleActiveTime)
        callerIsUser
        mintLimit(_laziNameQty, freeMaxLaziNamePerWallet)
        laziNameAvailable(_laziNameQty)
    {
        require(
            _totalMinted() < freeLaziName,
            "LaziName max free limit reached"
        );

        _mint(msg.sender, _laziNameQty);
    }

    // withdraw eth
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // setters
    function setLaziNamePrice(uint256 _newPrice) external onlyOwner {
        laziNamePrice = _newPrice;
    }

    function setFreeLaziName(uint256 _freeLaziName) external onlyOwner {
        freeLaziName = _freeLaziName;
    }

    function setFirstFreeMints(uint256 _firstFreeMints) external onlyOwner {
        firstFreeMints = _firstFreeMints;
    }

    function setReservedLaziName(uint256 _reservedLaziName) external onlyOwner {
        reservedLaziName = _reservedLaziName;
    }

    function setMaxLaziNamePerWallet(
        uint256 _maxLaziNamePerWallet,
        uint256 _freeMaxLaziNamePerWallet
    ) external onlyOwner {
        maxLaziNamePerWallet = _maxLaziNamePerWallet;
        freeMaxLaziNamePerWallet = _freeMaxLaziNamePerWallet;
    }

    function setSaleActiveTime(
        uint256 _saleActiveTime,
        uint256 _freeSaleActiveTime
    ) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setLaziNameMetadataURI(string memory _laziNameMetadataURI)
        external
        onlyOwner
    {
        laziNameMetadataURI = _laziNameMetadataURI;
    }

    function setRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return laziNameMetadataURI;
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

    modifier mintLimit(uint256 _laziNameQty, uint256 _maxLaziNamePerWallet) {
        require(
            _numberMinted(msg.sender) + _laziNameQty <= _maxLaziNamePerWallet,
            "LaziName max x wallet exceeded"
        );
        _;
    }

    modifier laziNameAvailable(uint256 _laziNameQty) {
        require(
            _laziNameQty + totalSupply() + reservedLaziName <= maxSupply,
            "Currently are sold out"
        );
        _;
    }

    modifier priceAvailable(uint256 _laziNameQty) {
        require(
            msg.value == _laziNameQty * laziNamePrice,
            "Hey hey, send the right amount of ETH"
        );
        _;
    }

    function getPrice(uint256 _qty) public view returns (uint256 price) {
        uint256 minted = _numberMinted(msg.sender) + _qty;
        if (minted > firstFreeMints)
            price = (minted - firstFreeMints) * laziNamePrice;
    }

    modifier priceAvailableFirstNftFree(uint256 _laziNameQty) {
        require(
            msg.value == getPrice(_laziNameQty),
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
}
