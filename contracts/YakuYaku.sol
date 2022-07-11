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

contract YakuYakuSale is
    ERC721A("YakuYaku", "YY"),
    Ownable,
    ERC721AQueryable,
    ERC721ABurnable,
    ERC2981
{
    uint256 public constant maxSupply = 9999;
    uint256 public reservedYakuYaku = 999;

    uint256 public freeYakuYaku = 0;
    uint256 public freeMaxYakuYakuPerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public freeYakuyakuPerWallet = 1;
    uint256 public maxYakuYakuPerWallet = 3;
    uint256 public yakuyakuPrice = 0.02 ether;
    uint256 public saleActiveTime = type(uint256).max;

    string yakuyakuMetadataURI;

    mapping(address => bool) private allowed; // YakuYaku Auto Approves Marketplaces So that people save their eth while listing YakuYaku on Marketplaces

    // these lines are called only once when the contract is deployed
    constructor() {
        approveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
        approveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        approveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        approveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        approveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
    }

    // public functions
    function buyYakuYaku(uint256 _yakuyakuQty)
        external
        payable
        saleActive(saleActiveTime)
        callerIsUser
        mintLimit(_yakuyakuQty, maxYakuYakuPerWallet)
        priceAvailableFirstNftFree(_yakuyakuQty)
        yakuyakuAvailable(_yakuyakuQty)
    {
        require(_totalMinted() >= freeYakuYaku, "Get your free YakuYaku");

        _mint(msg.sender, _yakuyakuQty);
    }

    function buyYakuYakuFree(uint256 _yakuyakuQty)
        external
        saleActive(freeSaleActiveTime)
        callerIsUser
        mintLimit(_yakuyakuQty, freeMaxYakuYakuPerWallet)
        yakuyakuAvailable(_yakuyakuQty)
    {
        require(
            _totalMinted() < freeYakuYaku,
            "YakuYaku max free limit reached"
        );

        _mint(msg.sender, _yakuyakuQty);
    }

    // only owner functions

    function approveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
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

    function setFreeYakuyakuPerWallet(uint256 _freeYakuyakuPerWallet)
        external
        onlyOwner
    {
        freeYakuyakuPerWallet = _freeYakuyakuPerWallet;
    }

    function setReservedYakuYaku(uint256 _reservedYakuYaku) external onlyOwner {
        reservedYakuYaku = _reservedYakuYaku;
    }

    function setMaxYakuYakuPerWallet(
        uint256 _maxYakuYakuPerWallet,
        uint256 _freeMaxYakuYakuPerWallet
    ) external onlyOwner {
        maxYakuYakuPerWallet = _maxYakuYakuPerWallet;
        freeMaxYakuYakuPerWallet = _freeMaxYakuYakuPerWallet;
    }

    function setSaleActiveTime(
        uint256 _saleActiveTime,
        uint256 _freeSaleActiveTime
    ) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setYakuYakuMetadataURI(string memory _yakuyakuMetadataURI)
        external
        onlyOwner
    {
        yakuyakuMetadataURI = _yakuyakuMetadataURI;
    }

    function giftYakuYaku(address[] calldata _sendNftsTo, uint256 _yakuyakuQty)
        external
        onlyOwner
        yakuyakuAvailable(_sendNftsTo.length * _yakuyakuQty)
    {
        reservedYakuYaku -= _sendNftsTo.length * _yakuyakuQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _yakuyakuQty);
    }

    function setRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // override functions
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override(ERC721A, IERC721)
        returns (bool)
    {
        return
            allowed[_operator]
                ? true
                : super.isApprovedForAll(_owner, _operator);
    }

    function _baseURI() internal view override returns (string memory) {
        return yakuyakuMetadataURI;
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

    // modifier functions
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is a sm");
        _;
    }

    modifier saleActive(uint256 _saleActiveTime) {
        require(
            block.timestamp > _saleActiveTime,
            "YakuYaku sale is still closed"
        );
        _;
    }

    modifier mintLimit(uint256 _yakuyakuQty, uint256 _maxYakuYakuPerWallet) {
        require(
            _numberMinted(msg.sender) + _yakuyakuQty <= _maxYakuYakuPerWallet,
            "YakuYaku max x wallet exceeded"
        );
        _;
    }

    modifier yakuyakuAvailable(uint256 _yakuyakuQty) {
        require(
            _yakuyakuQty + totalSupply() + reservedYakuYaku <= maxSupply,
            "2late...YakuYaku is sold out"
        );
        _;
    }

    modifier priceAvailable(uint256 _yakuyakuQty) {
        require(
            msg.value == _yakuyakuQty * yakuyakuPrice,
            "You need the right amount of ETH"
        );
        _;
    }

    function getPrice(uint256 _yakuyakuQty)
        public
        view
        returns (uint256 price)
    {
        uint256 yakuyakuMinted = _numberMinted(msg.sender) + _yakuyakuQty;
        if (yakuyakuMinted > freeYakuyakuPerWallet)
            price = (yakuyakuMinted - freeYakuyakuPerWallet) * yakuyakuPrice;
    }

    modifier priceAvailableFirstNftFree(uint256 _yakuyakuQty) {
        require(
            msg.value == getPrice(_yakuyakuQty),
            "You need the right amount of ETH"
        );
        _;
    }
}

contract YakuYakuStaking is YakuYakuSale {
    mapping(address => bool) public canStake;
    mapping(uint256 => bool) public staked;

    function addToWhitelistForStaking(address _operator) external onlyOwner {
        canStake[_operator] = !canStake[_operator];
    }

    function _beforeTokenTransfers(
        address,
        address,
        uint256 startTokenId,
        uint256
    ) internal view override {
        require(!staked[startTokenId], "Unstake your YakuYaku 1st");
    }

    function stakeYakuYaku(uint256[] calldata _tokenIds, bool _stake) external {
        require(canStake[msg.sender], "This contract is not allowed to stake");
        for (uint256 i = 0; i < _tokenIds.length; i++)
            staked[_tokenIds[i]] = _stake;
    }
}

contract YakuYaku is YakuYakuStaking {}
