// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "erc721a@3.3.0/contracts/ERC721A.sol";
import "erc721a@3.3.0/contracts/extensions/ERC721ABurnable.sol";
import "erc721a@3.3.0/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract YakuYakuSale is ERC721A("YakuYaku", "YY"), Ownable, ERC721AQueryable, ERC721ABurnable, ERC2981 {
    uint256 public constant maxSupply = 9999;
    uint256 public reservedYakuYaku = 999;

    uint256 public freeYakuYaku = 0;
    uint256 public freeMaxYakuYakuPerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public firstFreeMints = 1;
    uint256 public maxYakuYakuPerWallet = 3;
    uint256 public yakuyakuPrice = 0.02 ether;
    uint256 public saleActiveTime = type(uint256).max;

    string yakuyakuMetadataURI;

    function buyYakuYaku(uint256 _yakuyakuQty) external payable saleActive(saleActiveTime) callerIsUser mintLimit(_yakuyakuQty, maxYakuYakuPerWallet) priceAvailableFirstNftFree(_yakuyakuQty) yakuyakuAvailable(_YakuYakuQty) {
        require(_totalMinted() >= freeYakuYaku, "Get your free YakuYaku");

        _mint(msg.sender, _YakuYakuQty);
    }

    function buyYakuYakuFree(uint256 _yakuyakuQty) external saleActive(freeSaleActiveTime) callerIsUser mintLimit(_yakuyakuQty, freeMaxYakuYakuPerWallet) yakuyakuAvailable(_yakuyakuQty) {
        require(_totalMinted() < freeYakuYaku, "YakuYaku max free limit reached");

        _mint(msg.sender, _yakuyakuQty);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setYakuYakuPrice(uint256 _newPrice) external onlyOwner {
        yakuyakuPrice = _newPrice;
    }

    function setFreeYakuYaku(uint256 _freeYakuYaku) external onlyOwner {
        freeYakuYaku = _freeYakuYaku;
    }

    function setFirstFreeMints(uint256 _firstFreeMints) external onlyOwner {
        firstFreeMints = _firstFreeMints;
    }

    function setReservedYakuYaku(uint256 _reservedYakuYaku) external onlyOwner {
        reservedYakuYaku = _reservedYakuYaku;
    }

    function setMaxYakuYakuPerWallet(uint256 _maxYakuYakuPerWallet, uint256 _freeMaxYakuYakuPerWallet) external onlyOwner {
        maxYakuYakuPerWallet = _maxYakuYakuPerWallet;
        freeMaxYakuYakuPerWallet = _freeMaxYakuYakuPerWallet;
    }

    function setSaleActiveTime(uint256 _saleActiveTime, uint256 _freeSaleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setYakuYakuMetadataURI(string memory _yakuyakuMetadataURI) external onlyOwner {
        yakuyakuMetadataURI = _yakuyakuMetadataURI;
    }

    function giftYakuYaku(address[] calldata _sendNftsTo, uint256 _yakuyakuQty) external onlyOwner yakuyakuAvailable(_sendNftsTo.length * _yakuyakuQty) {
        reservedYakuYaku -= _sendNftsTo.length * _yakuyakuQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++) _safeMint(_sendNftsTo[i], _yakuyakuQty);
    }

    function _baseURI() internal view override returns (string memory) {
        return yakuyakuMetadataURI;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is a sm");
        _;
    }

    modifier saleActive(uint256 _saleActiveTime) {
        require(block.timestamp > _saleActiveTime, "YakuYaku sale is still closed");
        _;
    }

    modifier mintLimit(uint256 _yakuyakuQty, uint256 _maxYakuYakuPerWallet) {
        require(_numberMinted(msg.sender) + _YakuYakuQty <= _maxYakuYakuPerWallet, "YakuYaku max x wallet exceeded");
        _;
    }

    modifier yakuyakuAvailable(uint256 _yakuyakuQty) {
        require(_yakuyakuQty + totalSupply() + reservedYakuYaku <= maxSupply, "2late...YakuYaku is sold out");
        _;
    }

    modifier priceAvailable(uint256 _yakuyakuQty) {
        require(msg.value == _yakuyakuQty * yakuyakuPrice, "You need the right amount of ETH");
        _;
    }

    function getPrice(uint256 _qty) public view returns (uint256 price) {
        uint256 totalPrice = _qty * yakuyakuPrice;
        uint256 numberMinted = _numberMinted(msg.sender);
        uint256 discountQty = firstFreeMints > numberMinted ? firstFreeMints - numberMinted : 0;
        uint256 discount = discountQty * yakuyakuPrice;
        price = totalPrice > discount ? totalPrice - discount : 0;
    }

    modifier priceAvailableFirstNftFree(uint256 _yakuyakuQty) {
        require(msg.value == getPrice(_yakuyakuQty), "You need the right amount of ETH");
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
}

contract YakuYakuApprovesMarketplaces is YakuYakuSale {
    mapping(address => bool) private allowed;

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
    }

    function isApprovedForAll(address _owner, address _operator) public view override(ERC721A, IERC721) returns (bool) {
        // Opensea, LooksRare, Rarible, X2y2, Any Other Marketplace

        if (_operator == OpenSea(0xa5409ec958C83C3f309868babACA7c86DCB077c1).proxies(_owner)) return true;
        else if (_operator == 0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e) return true;
        else if (_operator == 0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be) return true;
        else if (_operator == 0xF849de01B080aDC3A814FaBE1E2087475cF2E354) return true;
        else if (allowed[_operator]) return true;
        return super.isApprovedForAll(_owner, _operator);
    }
}

contract YakuYakuStaking is YakuYakuApprovesMarketplaces {
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
        require(!staked[startTokenId], "Unstake your YakuYaku 1st");
    }

    function stakeYakuYaku(uint256[] calldata _tokenIds, bool _stake) external onlyWhitelistedForStaking {
        for (uint256 i = 0; i < _tokenIds.length; i++) staked[_tokenIds[i]] = _stake;
    }
}

interface OpenSea {
    function proxies(address) external view returns (address);
}

contract YakuYaku is YakuYakuStaking {}
