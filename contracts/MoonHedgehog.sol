// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

// import "erc721a@3.3.0/contracts/ERC721A.sol";
// import "erc721a@3.3.0/contracts/extensions/ERC721ABurnable.sol";
// import "erc721a@3.3.0/contracts/extensions/ERC721AQueryable.sol";

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract MoonHedgehogSale is ERC721A("MoonHedgehog", "MH"), Ownable, ERC721AQueryable, ERC721ABurnable, ERC2981 {
    uint256 public constant maxSupply = 9999;
    uint256 public reservedHedgehog = 999;

    uint256 public freeHedgehog = 0;
    uint256 public freeMaxHedgehogPerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public firstFreeMints = 1;
    uint256 public maxHedgehogPerWallet = 3;
    uint256 public hedgehogPrice = 0.01 ether;
    uint256 public saleActiveTime = type(uint256).max;

    string hedgehogMetadataURI;

    constructor(){
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
    }

    function buyHedgehog(uint256 _hedgehogQty) external payable saleActive(saleActiveTime) callerIsUser mintLimit(_hedgehogQty, maxHedgehogPerWallet) priceAvailableFirstNftFree(_hedgehogQty) hedgehogAvailable(_hedgehogQty) {
        require(_totalMinted() >= freeHedgehog, "Get your MoonHedgehog for free");

        _mint(msg.sender, _hedgehogQty);
    }

    function buyHedgehogFree(uint256 _hedgehogQty) external saleActive(freeSaleActiveTime) callerIsUser mintLimit(_hedgehogQty, freeMaxHedgehogPerWallet) hedgehogAvailable(_hedgehogQty) {
        require(_totalMinted() < freeHedgehog, "MoonHedgehog max free limit reached");

        _mint(msg.sender, _hedgehogQty);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setHedgehogPrice(uint256 _newPrice) external onlyOwner {
        hedgehogPrice = _newPrice;
    }

    function setFreeHedgehog(uint256 _freeHedgehog) external onlyOwner {
        freeHedgehog = _freeHedgehog;
    }

    function setFirstFreeMints(uint256 _firstFreeMints) external onlyOwner {
        firstFreeMints = _firstFreeMints;
    }

    function setReservedHedgehog(uint256 _reservedHedgehog) external onlyOwner {
        reservedHedgehog = _reservedHedgehog;
    }

    function setMaxHedgehogPerWallet(uint256 _maxHedgehogPerWallet, uint256 _freeMaxHedgehogPerWallet) external onlyOwner {
        maxHedgehogPerWallet = _maxHedgehogPerWallet;
        freeMaxHedgehogPerWallet = _freeMaxHedgehogPerWallet;
    }

    function setSaleActiveTime(uint256 _saleActiveTime, uint256 _freeSaleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setHedgehogMetadataURI(string memory _hedgehogMetadataURI) external onlyOwner {
        hedgehogMetadataURI = _hedgehogMetadataURI;
    }

    function giftHedgehog(address[] calldata _sendNftsTo, uint256 _hedgehogQty) external onlyOwner hedgehogAvailable(_sendNftsTo.length * _hedgehogQty) {
        reservedHedgehog -= _sendNftsTo.length * _hedgehogQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++) _safeMint(_sendNftsTo[i], _hedgehogQty);
    }

    function _baseURI() internal view override returns (string memory) {
        return hedgehogMetadataURI;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is a sm");
        _;
    }

    modifier saleActive(uint256 _saleActiveTime) {
        require(block.timestamp > _saleActiveTime, "Sorry but sale is not open");
        _;
    }

    modifier mintLimit(uint256 _hedgehogQty, uint256 _maxHedgehogPerWallet) {
        require(_numberMinted(msg.sender) + _hedgehogQty <= _maxHedgehogPerWallet, "MoonHedgehog max x wallet exceeded");
        _;
    }

    modifier hedgehogAvailable(uint256 _hedgehogQty) {
        require(_hedgehogQty + totalSupply() + reservedHedgehog <= maxSupply, "Currently are sold out");
        _;
    }

    modifier priceAvailable(uint256 _hedgehogQty) {
        require(msg.value == _hedgehogQty * hedgehogPrice, "Hey hey, send the right amount of ETH");
        _;
    }

    function getPrice(uint256 _qty) public view returns (uint256 price) {
        uint256 totalPrice = _qty * hedgehogPrice;
        uint256 numberMinted = _numberMinted(msg.sender);
        uint256 discountQty = firstFreeMints > numberMinted ? firstFreeMints - numberMinted : 0;
        uint256 discount = discountQty * hedgehogPrice;
        price = totalPrice > discount ? totalPrice - discount : 0;
    }

    modifier priceAvailableFirstNftFree(uint256 _hedgehogQty) {
        require(msg.value == getPrice(_hedgehogQty), "Hey hey, send the right amount of ETH");
        _;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC165, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setRoyalty(address _receiver, uint96 _feeNumerator) public onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Hedgehog Auto Approves Marketplaces
    mapping(address => bool) private allowed;

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
    }

    function isApprovedForAll(address _owner, address _operator) public view override(ERC721A, IERC721) returns (bool) {
        if (_operator == OpenSea(0xa5409ec958C83C3f309868babACA7c86DCB077c1).proxies(_owner)) return true;
        else if (allowed[_operator]) return true; // Opensea or any other Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}

contract MoonHedgehogStaking is MoonHedgehogSale {
    mapping(address => bool) public canStake;

    function addToWhitelistForStaking(address _operator) external onlyOwner {
        canStake[_operator] = !canStake[_operator];
    }

    modifier onlyWhitelistedForStaking() {
        require(canStake[msg.sender], "This contract is not allowed to stake");
        _;
    }

    mapping(uint256 => bool) public staked;

    function _beforeTokenTransfers(
        address,
        address,
        uint256 startTokenId,
        uint256
    ) internal view override {
        require(!staked[startTokenId], "Nope, unstake your MoonHedgehog first");
    }

    function stakeHedgehog(uint256[] calldata _tokenIds, bool _stake) external onlyWhitelistedForStaking {
        for (uint256 i = 0; i < _tokenIds.length; i++) staked[_tokenIds[i]] = _stake;
    }
}

interface OpenSea {
    function proxies(address) external view returns (address);
}

contract MoonHedgehog is MoonHedgehogStaking {}
