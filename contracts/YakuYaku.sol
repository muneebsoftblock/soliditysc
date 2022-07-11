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

contract JohnSale is
    ERC721A("John", "YY"),
    Ownable,
    ERC721AQueryable,
    ERC721ABurnable,
    ERC2981
{
    uint256 public constant maxSupply = 9999;
    uint256 public reservedJohn = 999;

    uint256 public freeJohn = 0;
    uint256 public freeMaxJohnPerWallet = 0;
    uint256 public freeSaleActiveTime = type(uint256).max;

    uint256 public freeJohnPerWallet = 1;
    uint256 public maxJohnPerWallet = 3;
    uint256 public johnPrice = 0.02 ether;
    uint256 public saleActiveTime = type(uint256).max;

    string johnMetadataURI;

    mapping(address => bool) private allowed; // John Auto Approves Marketplaces So that people save their eth while listing John on Marketplaces

    // public functions
    function buyJohn(uint256 _johnQty)
        external
        payable
        saleActive(saleActiveTime)
        callerIsUser
        mintLimit(_johnQty, maxJohnPerWallet)
        priceAvailableFirstNftFree(_johnQty)
        johnAvailable(_johnQty)
    {
        require(_totalMinted() >= freeJohn, "Get your free John");

        _mint(msg.sender, _johnQty);
    }

    function buyJohnFree(uint256 _johnQty)
        external
        saleActive(freeSaleActiveTime)
        callerIsUser
        mintLimit(_johnQty, freeMaxJohnPerWallet)
        johnAvailable(_johnQty)
    {
        require(
            _totalMinted() < freeJohn,
            "John max free limit reached"
        );

        _mint(msg.sender, _johnQty);
    }

    // only owner functions

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setJohnPrice(uint256 _newPrice) external onlyOwner {
        johnPrice = _newPrice;
    }

    function setFreeJohn(uint256 _freeJohn) external onlyOwner {
        freeJohn = _freeJohn;
    }

    function setFreeJohnPerWallet(uint256 _freeJohnPerWallet)
        external
        onlyOwner
    {
        freeJohnPerWallet = _freeJohnPerWallet;
    }

    function setReservedJohn(uint256 _reservedJohn) external onlyOwner {
        reservedJohn = _reservedJohn;
    }

    function setMaxJohnPerWallet(
        uint256 _maxJohnPerWallet,
        uint256 _freeMaxJohnPerWallet
    ) external onlyOwner {
        maxJohnPerWallet = _maxJohnPerWallet;
        freeMaxJohnPerWallet = _freeMaxJohnPerWallet;
    }

    function setSaleActiveTime(
        uint256 _saleActiveTime,
        uint256 _freeSaleActiveTime
    ) external onlyOwner {
        saleActiveTime = _saleActiveTime;
        freeSaleActiveTime = _freeSaleActiveTime;
    }

    function setJohnMetadataURI(string memory _johnMetadataURI)
        external
        onlyOwner
    {
        johnMetadataURI = _johnMetadataURI;
    }

    function giftJohn(address[] calldata _sendNftsTo, uint256 _johnQty)
        external
        onlyOwner
        johnAvailable(_sendNftsTo.length * _johnQty)
    {
        reservedJohn -= _sendNftsTo.length * _johnQty;
        for (uint256 i = 0; i < _sendNftsTo.length; i++)
            _safeMint(_sendNftsTo[i], _johnQty);
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
        return johnMetadataURI;
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
            "John sale is still closed"
        );
        _;
    }

    modifier mintLimit(uint256 _johnQty, uint256 _maxJohnPerWallet) {
        require(
            _numberMinted(msg.sender) + _johnQty <= _maxJohnPerWallet,
            "John max x wallet exceeded"
        );
        _;
    }

    modifier johnAvailable(uint256 _johnQty) {
        require(
            _johnQty + totalSupply() + reservedJohn <= maxSupply,
            "2late...John is sold out"
        );
        _;
    }

    modifier priceAvailable(uint256 _johnQty) {
        require(
            msg.value == _johnQty * johnPrice,
            "You need the right amount of ETH"
        );
        _;
    }

    function getPrice(uint256 _johnQty)
        public
        view
        returns (uint256 price)
    {
        uint256 johnMinted = _numberMinted(msg.sender) + _johnQty;
        if (johnMinted > freeJohnPerWallet)
            price = (johnMinted - freeJohnPerWallet) * johnPrice;
    }

    modifier priceAvailableFirstNftFree(uint256 _johnQty) {
        require(
            msg.value == getPrice(_johnQty),
            "You need the right amount of ETH"
        );
        _;
    }
}

contract JohnStaking is JohnSale {
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
        require(!staked[startTokenId], "Unstake your John 1st");
    }

    function stakeJohn(uint256[] calldata _tokenIds, bool _stake) external {
        require(canStake[msg.sender], "This contract is not allowed to stake");
        for (uint256 i = 0; i < _tokenIds.length; i++)
            staked[_tokenIds[i]] = _stake;
    }
}

contract John is JohnStaking {}
