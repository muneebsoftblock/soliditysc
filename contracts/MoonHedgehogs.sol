// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract DigiCollectSale is
    ERC721A("Digi Collect Labs", "DCL"),
    Ownable,
    ERC721AQueryable,
    ERC721ABurnable,
    ERC2981
{
    // Variables
    uint256 public constant maxSupply = 10000;
    uint256 public reservedDigiCollect = 500;

    uint256 public freeDigiCollect = 0;
    uint256 public freeMaxDigiCollectPerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public firstFreeMints = 1;
    uint256 public maxDigiCollectPerWallet = 2;
    uint256 public digiCollectPrice = 0.01 ether;
    uint256 public saleActiveTime = type(uint256).max;

    string digiCollectMetadataURI;

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
        saleActive(saleActiveTime)
        callerIsUser
        mintLimit(_digiCollectQty, maxDigiCollectPerWallet)
        priceAvailableFirstNftFree(_digiCollectQty)
        digiCollectAvailable(_digiCollectQty)
    {
        require(
            _totalMinted() >= freeDigiCollect,
            "Get your DigiCollect for free"
        );

        _mint(msg.sender, _digiCollectQty);
    }

    function buyDigiCollectFree(uint256 _digiCollectQty)
        external
        saleActive(freeSaleActiveTime)
        callerIsUser
        mintLimit(_digiCollectQty, freeMaxDigiCollectPerWallet)
        digiCollectAvailable(_digiCollectQty)
    {
        require(
            _totalMinted() < freeDigiCollect,
            "DigiCollect max free limit reached"
        );

        _mint(msg.sender, _digiCollectQty);
    }

    // withdraw eth
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // setters
    function setDigiCollectPrice(uint256 _newPrice) external onlyOwner {
        digiCollectPrice = _newPrice;
    }

    function setFreeDigiCollect(uint256 _freeDigiCollect) external onlyOwner {
        freeDigiCollect = _freeDigiCollect;
    }

    function setFirstFreeMints(uint256 _firstFreeMints) external onlyOwner {
        firstFreeMints = _firstFreeMints;
    }

    function setReservedDigiCollect(uint256 _reservedDigiCollect)
        external
        onlyOwner
    {
        reservedDigiCollect = _reservedDigiCollect;
    }

    function setMaxDigiCollectPerWallet(
        uint256 _maxDigiCollectPerWallet,
        uint256 _freeMaxDigiCollectPerWallet
    ) external onlyOwner {
        maxDigiCollectPerWallet = _maxDigiCollectPerWallet;
        freeMaxDigiCollectPerWallet = _freeMaxDigiCollectPerWallet;
    }

    function setSaleActiveTime(
        uint256 _saleActiveTime,
        uint256 _freeSaleActiveTime
    ) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setDigiCollectMetadataURI(string memory _digiCollectMetadataURI)
        external
        onlyOwner
    {
        digiCollectMetadataURI = _digiCollectMetadataURI;
    }

    function setRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return digiCollectMetadataURI;
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

    modifier mintLimit(uint256 _digiCollectQty, uint256 _maxDigiCollectPerWallet) {
        require(
            _numberMinted(msg.sender) + _digiCollectQty <= _maxDigiCollectPerWallet,
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

    modifier priceAvailable(uint256 _digiCollectQty) {
        require(
            msg.value == _digiCollectQty * digiCollectPrice,
            "Hey hey, send the right amount of ETH"
        );
        _;
    }

    function getPrice(uint256 _qty) public view returns (uint256 price) {
        uint256 minted = _numberMinted(msg.sender) + _qty;
        if (minted > firstFreeMints)
            price = (minted - firstFreeMints) * digiCollectPrice;
    }

    modifier priceAvailableFirstNftFree(uint256 _digiCollectQty) {
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
        if (
            _operator ==
            OpenSea(0xa5409ec958C83C3f309868babACA7c86DCB077c1).proxies(_owner)
        ) return true;
        else if (allowed[_operator]) return true; // Opensea or any other Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}

contract DigiCollectStaking is DigiCollectSale {
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
        require(
            !staked[startTokenId],
            "Nope, unstake your DigiCollect first"
        );
    }

    function stakeDigiCollect(uint256[] calldata _tokenIds, bool _stake)
        external
        onlyWhitelistedForStaking
    {
        for (uint256 i = 0; i < _tokenIds.length; i++)
            staked[_tokenIds[i]] = _stake;
    }
}

interface OpenSea {
    function proxies(address) external view returns (address);
}

contract DigiCollect is DigiCollectStaking {}
